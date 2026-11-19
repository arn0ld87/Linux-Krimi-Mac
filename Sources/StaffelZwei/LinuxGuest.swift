import Darwin
import Foundation
import StaffelCore
import Virtualization

/// Serial transport and lifecycle of the local Alpine guest.
final class LinuxGuest: NSObject, VZVirtualMachineDelegate {
    struct Reply: Decodable {
        let id: UUID?
        let ready: Bool?
        let cwd: String?
        let output: String?
        let failed: Bool?
        let files: [String: String]?
        let checks: Set<String>?
        let accepted: Bool?
        let error: String?
    }

    private struct Request: Encodable {
        let id: UUID
        let command: String
        let cwd: String
        let seed: [String: String]?
        let episode: Int
        let step: String?
        let answer: String?
        let desktop: String?
    }

    private let directory: URL
    private let episode: Int
    private var machine: VZVirtualMachine?
    private var input: Pipe?
    private var output: Pipe?
    private var diskLock: FileHandle?
    private var pending: (UUID, CheckedContinuation<Reply, any Error>)?
    private var deadline: Task<Void, Never>?
    private var buffer = Data()
    private var bootLog = ""
    private var ready = false
    private var bootFailure: String?
    private let writer = DispatchQueue(label: "StaffelZwei.LinuxGuest.input")

    private var disk: URL { directory.appendingPathComponent("linux-arm64.raw") }
    var displayMachine: VZVirtualMachine? { machine }

    init(directory: URL, episode: Int = 0) {
        self.directory = directory
        self.episode = episode
    }

    func connect(cwd: String, seed: [String: String]) async throws -> Reply {
        if ready {
            return try await exchange(command: "", cwd: cwd, seed: nil)
        }
        do {
            try startConfiguration()
            guard let machine else { throw GuestError("Linux konnte nicht eingerichtet werden.") }
            try await machine.start()
            let limit = ContinuousClock.now + .seconds(22)
            while !ready, bootFailure == nil, ContinuousClock.now < limit {
                try await Task.sleep(for: .milliseconds(50))
            }
            guard ready else {
                throw GuestError(bootFailure ?? "Linux antwortet beim Start nicht. \(bootLog)")
            }
            return try await exchange(command: "", cwd: cwd, seed: seed)
        } catch {
            try? await stop()
            throw error
        }
    }

    func run(_ command: String, cwd: String) async throws -> Reply {
        guard ready else { throw GuestError("Linux ist noch nicht bereit.") }
        return try await exchange(command: command, cwd: cwd, seed: nil)
    }

    func answer(_ answer: String, for step: String, cwd: String) async throws -> Reply {
        try await exchange(command: "", cwd: cwd, seed: nil, step: step, answer: answer)
    }

    func desktop(_ action: String, cwd: String) async throws -> Reply {
        try await exchange(command: "", cwd: cwd, seed: nil, desktop: action)
    }

    func stop() async throws {
        if let machine, machine.canStop { try await machine.stop() }
        release()
    }

    /// The old image stays available next to the JSON backup after a reset.
    func withArchivedDisk(_ reset: () throws -> Void) throws {
        try acquireLock()
        defer { diskLock = nil }
        guard FileManager.default.fileExists(atPath: disk.path) else {
            try reset()
            return
        }
        let backup = directory.appendingPathComponent("linux-arm64-backup-\(UUID().uuidString).raw")
        try FileManager.default.moveItem(at: disk, to: backup)
        do {
            try reset()
        } catch {
            try FileManager.default.moveItem(at: backup, to: disk)
            throw error
        }
    }

    private func startConfiguration() throws {
        guard VZVirtualMachine.isSupported,
              let kernel = Bundle.main.url(forResource: "Image", withExtension: nil, subdirectory: "LinuxGuest"),
              let initrd = Bundle.main.url(forResource: "initramfs.cpio", withExtension: "gz", subdirectory: "LinuxGuest")
        else { throw GuestError("Das ARM64-Linux-Abbild ist auf diesem Mac nicht verfügbar.") }

        try acquireLock()
        if !FileManager.default.fileExists(atPath: disk.path) {
            let fd = open(disk.path, O_RDWR | O_CREAT | O_EXCL | O_NOFOLLOW, 0o600)
            guard fd != -1 else {
                throw GuestError("Die virtuelle Festplatte konnte nicht angelegt werden.")
            }
            let file = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
            defer { try? file.close() }
            try file.truncate(atOffset: 256 * 1024 * 1024)
        }
        let properties = try disk.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
        guard properties.isRegularFile == true, properties.isSymbolicLink == false,
              properties.fileSize == 256 * 1024 * 1024 else {
            throw GuestError("Die virtuelle Festplatte hat ein unerwartetes Format.")
        }

        let config = VZVirtualMachineConfiguration()
        config.cpuCount = 2
        config.memorySize = 1280 * 1024 * 1024
        if BrowserMission.supportsDesktop(episode) {
            let graphics = VZVirtioGraphicsDeviceConfiguration()
            graphics.scanouts = [VZVirtioGraphicsScanoutConfiguration(widthInPixels: 1024, heightInPixels: 768)]
            config.graphicsDevices = [graphics]
            config.keyboards = [VZUSBKeyboardConfiguration()]
            config.pointingDevices = [VZUSBScreenCoordinatePointingDeviceConfiguration()]
        }
        let loader = VZLinuxBootLoader(kernelURL: kernel)
        loader.initialRamdiskURL = initrd
        loader.commandLine = "console=hvc0 quiet loglevel=3 panic=-1"
        config.bootLoader = loader
        let attachment = try VZDiskImageStorageDeviceAttachment(url: disk, readOnly: false)
        config.storageDevices = [VZVirtioBlockDeviceConfiguration(attachment: attachment)]

        let input = Pipe()
        let output = Pipe()
        let port = VZVirtioConsoleDeviceSerialPortConfiguration()
        port.attachment = VZFileHandleSerialPortAttachment(
            fileHandleForReading: input.fileHandleForReading, fileHandleForWriting: output.fileHandleForWriting
        )
        config.serialPorts = [port]
        try config.validate()

        let vm = VZVirtualMachine(configuration: config)
        vm.delegate = self
        machine = vm
        self.input = input
        self.output = output
        output.fileHandleForReading.readabilityHandler = { @Sendable [weak self] handle in
            let data = handle.availableData
            DispatchQueue.main.async { [weak self] in
                guard let self, self.output?.fileHandleForReading === handle else { return }
                self.receive(data)
            }
        }
    }

    private func acquireLock() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("linux-arm64.lock")
        let fd = open(url.path, O_RDWR | O_CREAT | O_NOFOLLOW, 0o600)
        guard fd != -1 else { throw GuestError("Die virtuelle Festplatte kann nicht gesperrt werden.") }
        guard flock(fd, LOCK_EX | LOCK_NB) == 0 else {
            close(fd)
            throw GuestError("Dieser Spielstand ist bereits in einer anderen Instanz geöffnet.")
        }
        diskLock = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
    }

    private func exchange(command: String, cwd: String, seed: [String: String]?,
                          step: String? = nil, answer: String? = nil, desktop: String? = nil) async throws -> Reply {
        guard pending == nil, let handle = input?.fileHandleForWriting else {
            throw GuestError("Das Linux-Terminal ist belegt.")
        }
        let id = UUID()
        var encoded = try JSONEncoder().encode(Request(id: id, command: command, cwd: cwd, seed: seed,
                                                       episode: episode, step: step, answer: answer, desktop: desktop))
        encoded.append(0x0A)
        let data = encoded
        return try await withCheckedThrowingContinuation { continuation in
            pending = (id, continuation)
            deadline = Task { [weak self] in
                try? await Task.sleep(for: .seconds(seed == nil ? 18 : 32))
                guard !Task.isCancelled, let self, self.pending?.0 == id else { return }
                self.finish(.failure(GuestError("Zeitlimit beim Warten auf Linux.")))
            }
            writer.async { [weak self] in
                do {
                    try handle.write(contentsOf: data)
                } catch {
                    DispatchQueue.main.async { [weak self] in
                        guard let self, self.pending?.0 == id else { return }
                        self.finish(.failure(error))
                    }
                }
            }
        }
    }

    private func receive(_ data: Data) {
        guard !data.isEmpty else { return }
        buffer.append(data)
        guard buffer.count < 2 * 1024 * 1024 else {
            buffer.removeAll()
            finish(.failure(GuestError("Die Linux-Antwort war zu groß.")))
            return
        }
        while let newline = buffer.firstIndex(of: 0x0A) {
            let line = Data(buffer[..<newline])
            buffer.removeSubrange(...newline)
            guard let reply = try? JSONDecoder().decode(Reply.self, from: line) else {
                if !ready { bootLog = String((bootLog + String(decoding: line, as: UTF8.self) + "\n").suffix(1600)) }
                continue
            }
            if reply.ready == true {
                ready = true
            } else if let pending, reply.id == pending.0 {
                if let error = reply.error {
                    finish(.failure(GuestError(error)))
                } else {
                    finish(.success(reply))
                }
            } else if !ready {
                bootFailure = reply.error
            }
        }
    }

    private func finish(_ result: Result<Reply, any Error>) {
        deadline?.cancel()
        deadline = nil
        let continuation = pending?.1
        pending = nil
        continuation?.resume(with: result)
    }

    private func release() {
        output?.fileHandleForReading.readabilityHandler = nil
        output = nil
        input = nil
        machine?.delegate = nil
        machine = nil
        diskLock = nil
        buffer.removeAll()
        bootLog = ""
        ready = false
        bootFailure = nil
        finish(.failure(GuestError("Die Linux-VM wurde beendet.")))
    }

    func guestDidStop(_ virtualMachine: VZVirtualMachine) {
        release()
    }

    func virtualMachine(_ virtualMachine: VZVirtualMachine, didStopWithError error: any Error) {
        finish(.failure(error))
        release()
        bootFailure = error.localizedDescription
    }
}

private struct GuestError: LocalizedError {
    let errorDescription: String?

    init(_ message: String) { errorDescription = message }
}
