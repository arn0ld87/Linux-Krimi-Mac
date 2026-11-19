import Foundation
import SwiftUI
import StaffelCore
import Virtualization

/// Zentraler App-Zustand: hält die Engine, persistiert und steuert die Navigation.
@MainActor
@Observable
public final class AppModel {
    public private(set) var engine: GameEngine
    public private(set) var store: GameStore
    /// Fehlertext beim Laden (z. B. defekter Spielstand).
    public private(set) var loadWarning: String?
    /// Meldung nach einem Speichervorgang.
    public private(set) var statusMessage: String?
    public var appearance: AppearancePreference = .system
    var lastMichaInteraction = Date()
    public private(set) var terminalBusy = false
    private(set) var interactiveShellOpen = false
    private(set) var maintenanceShell = false
    private(set) var terminalPromptCount = 0
    var requestsMaintenance = false
    @ObservationIgnored lazy var terminalSurface = GuestTerminalSurface(model: self)
    @ObservationIgnored private var terminalRefresh: Task<Void, Never>?
    private var terminalSize = LinuxGuest.TerminalSize()
    public private(set) var linuxConnected = false
    public private(set) var linuxMessage = "Linux bereit zum Start"
    private(set) var desktopReady = false
    private(set) var desktopMessage: String?
    @ObservationIgnored private var guest: LinuxGuest
    private let campaign: GameStore

    public enum AppearancePreference: String, CaseIterable, Identifiable {
        case system, light, dark
        public var id: String { rawValue }
        public var title: String {
            switch self {
            case .system: return "System"
            case .light: return "Hell"
            case .dark: return "Dunkel"
            }
        }
        public var colorScheme: ColorScheme? {
            switch self {
            case .system: return nil
            case .light: return .light
            case .dark: return .dark
            }
        }
    }

    public init(store: GameStore = GameStore()) {
        campaign = store
        let selection = (try? String(contentsOf: Self.selectionURL(store), encoding: .utf8)).flatMap(Int.init)
        let episode = EpisodeCatalog.episode(id: selection ?? 0)
        let loaded = Self.load(Self.store(for: episode, in: store), episode: episode)
        guest = LinuxGuest(directory: loaded.store.directory, episode: episode.id)
        self.store = loaded.store
        engine = loaded.engine
        loadWarning = loaded.warning
    }

    private static func selectionURL(_ campaign: GameStore) -> URL {
        campaign.directory.appendingPathComponent("aktive-episode.txt")
    }

    private static func store(for episode: Episode, in campaign: GameStore) -> GameStore {
        guard episode.id != 0 else { return campaign }
        let directory = campaign.directory.appendingPathComponent("episoden", isDirectory: true)
            .appendingPathComponent(String(episode.id), isDirectory: true)
        return GameStore(directory: directory)
    }

    private static func load(_ store: GameStore, episode: Episode)
        -> (store: GameStore, engine: GameEngine, warning: String?) {
        var working = store
        let result = working.load()
        if case .corrupt = result {
            working.protectFromOverwrite()
        }
        let fresh = GameEngine(state: GameState(episode: episode))
        switch result {
        case .loaded(let state) where state.episodeID == episode.id:
            return (working, GameEngine(state: state), nil)
        case .loaded:
            working.protectFromOverwrite()
            return (working, fresh, "Der Spielstand gehört zu einer anderen Episode.")
        case .fresh:
            return (working, fresh, nil)
        case .corrupt(let reason):
            return (working, fresh, "Der Spielstand konnte nicht gelesen werden. Grund: \(reason)")
        }
    }

    public var state: GameState { engine.state }
    public var episode: Episode { engine.state.episode }
    var supportsDesktop: Bool { BrowserMission.supportsDesktop(episode.id) }

    // MARK: Navigation

    public var page: AppPage {
        get { engine.state.page }
        set {
            guard newValue != .desktop || supportsDesktop else { return }
            let leftDesktop = engine.state.page == .desktop && newValue != .desktop
            engine.setPage(newValue)
            persist()
            if leftDesktop { refreshGuest() }
        }
    }

    var desktopMachine: VZVirtualMachine? { desktopReady ? guest.displayMachine : nil }

    public func selectEpisode(_ episode: Episode) {
        guard episode.playable, !terminalBusy else { return }
        if episode.id == state.episodeID {
            page = .briefing
            return
        }
        terminalBusy = true
        Task {
            defer { terminalBusy = false }
            do {
                try await guest.stop()
                resetTerminal()
                linuxConnected = false
                desktopReady = false
                desktopMessage = nil
                linuxMessage = "Linux bereit zum Start"
                let loaded = Self.load(Self.store(for: episode, in: campaign), episode: episode)
                try FileManager.default.createDirectory(at: campaign.directory, withIntermediateDirectories: true)
                try Data(String(episode.id).utf8).write(to: Self.selectionURL(campaign), options: .atomic)
                store = loaded.store
                engine = loaded.engine
                guest = LinuxGuest(directory: store.directory, episode: episode.id)
                loadWarning = loaded.warning
                page = .briefing
            } catch {
                statusMessage = "Episodenwechsel fehlgeschlagen: \(error.localizedDescription)"
            }
        }
    }

    // MARK: Terminal

    public func runCommand(_ input: String) {
        let command = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !terminalBusy, !command.isEmpty else { return }
        guard command.utf8.count <= 16 * 1024 else {
            linuxMessage = "Der Linux-Befehl ist zu lang"
            return
        }
        if supportsDesktop, command == "bildschirm" {
            page = .desktop
            return
        }
        if command == "clear" {
            engine.clearTerminal()
            persist()
            return
        }
        terminalBusy = true
        Task {
            defer { terminalBusy = false }
            do {
                try await connectLinux()
                let reply = try await guest.run(command, cwd: state.cwd)
                applyLinux(reply)
                engine.recordLinuxCommand(command, output: reply.output ?? "", failed: reply.failed ?? false)
                persist()
            } catch {
                await reportLinuxError(error)
                engine.recordLinuxCommand(command, output: linuxMessage, failed: true)
                persist()
            }
        }
    }

    func startLinux() {
        guard !linuxConnected, !terminalBusy, !Snapshot.requested else { return }
        terminalBusy = true
        Task {
            defer { terminalBusy = false }
            do {
                try await connectLinux()
                persist()
            } catch {
                await reportLinuxError(error)
            }
        }
    }

    func openInteractiveTerminal(maintenance: Bool = false) async {
        guard !Snapshot.requested else { return }
        while terminalBusy, !Task.isCancelled, page == .terminal {
            try? await Task.sleep(for: .milliseconds(35))
        }
        guard !Task.isCancelled, page == .terminal,
              !interactiveShellOpen || maintenanceShell != maintenance else { return }
        terminalBusy = true
        defer { terminalBusy = false }
        do {
            try await connectLinux()
            guest.onTerminalEvent = { [weak self] event in self?.receiveTerminalEvent(event) }
            interactiveShellOpen = true
            maintenanceShell = maintenance
            try await guest.openTerminal(cwd: state.cwd, size: terminalSize, maintenance: maintenance)
            guest.resizeTerminal(terminalSize)
            persist()
        } catch {
            await reportLinuxError(error)
        }
    }

    func sendTerminalInput(_ bytes: Data) {
        guard interactiveShellOpen else { return }
        guest.sendTerminal(bytes)
    }

    func resizeTerminal(rows: Int, cols: Int) {
        let size = LinuxGuest.TerminalSize(rows: rows, cols: cols)
        guard size != terminalSize else { return }
        terminalSize = size
        if interactiveShellOpen { guest.resizeTerminal(size) }
    }

    private func receiveTerminalEvent(_ event: LinuxGuest.Reply) {
        if let bytes = event.terminalOutput { terminalSurface.feed(bytes) }
        if event.terminalDesktop == true, supportsDesktop, page == .terminal { page = .desktop }
        if event.terminalPrompt == true {
            terminalPromptCount += 1
            terminalRefresh?.cancel()
            terminalRefresh = Task { [weak self] in
                try? await Task.sleep(for: .milliseconds(60))
                guard let self else { return }
                while terminalBusy, !Task.isCancelled { try? await Task.sleep(for: .milliseconds(35)) }
                guard !Task.isCancelled else { return }
                refreshGuest()
            }
        }
        if event.terminalClosed == true {
            interactiveShellOpen = false
            maintenanceShell = false
            if page == .terminal { Task { await openInteractiveTerminal() } }
        }
    }

    private func resetTerminal() {
        terminalRefresh?.cancel()
        interactiveShellOpen = false
        maintenanceShell = false
        requestsMaintenance = false
        terminalSurface.clear()
    }

    private func connectLinux() async throws {
        guard !linuxConnected else { return }
        linuxMessage = "Alpine Linux startet …"
        let reply = try await guest.connect(cwd: state.cwd, seed: engine.linuxSeed)
        applyLinux(reply)
        linuxConnected = true
        linuxMessage = "Alpine Linux · ARM64 · Offline"
    }

    private func applyLinux(_ reply: LinuxGuest.Reply) {
        if let cwd = reply.cwd, let files = reply.files {
            engine.syncLinux(cwd: cwd, files: files, checks: reply.checks ?? [])
        }
    }

    func submitAnswer(_ value: String, for step: String) async -> String? {
        let answer = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !terminalBusy, !answer.isEmpty, answer.utf8.count <= 200 else {
            return "Gib eine kurze Antwort ein und warte auf Linux."
        }
        terminalBusy = true
        defer { terminalBusy = false }
        do {
            try await connectLinux()
            let reply = try await guest.answer(answer, for: step, cwd: state.cwd)
            applyLinux(reply)
            if reply.accepted == true {
                engine.markAnswer(step)
                persist()
                return nil
            }
            persist()
            return "Die Antwort stimmt noch nicht. Prüfe die Quelle und das Format."
        } catch {
            await reportLinuxError(error)
            return linuxMessage
        }
    }

    private func reportLinuxError(_ error: any Error) async {
        try? await guest.stop()
        resetTerminal()
        linuxConnected = false
        desktopReady = false
        desktopMessage = nil
        linuxMessage = "Linux: \(error.localizedDescription)"
    }

    func useDesktop(_ action: String) async {
        guard supportsDesktop, !terminalBusy else { return }
        terminalBusy = true
        defer { terminalBusy = false }
        desktopMessage = nil
        do {
            try await connectLinux()
            if !desktopReady {
                applyLinux(try await guest.desktop("start", cwd: state.cwd))
                desktopReady = true
                if action == "start", let initial = BrowserMission.forEpisode(episode.id)?.desktop?.initialApp {
                    applyLinux(try await guest.desktop(initial, cwd: state.cwd))
                }
            }
            if action != "start" {
                applyLinux(try await guest.desktop(action, cwd: state.cwd))
            }
            persist()
        } catch {
            desktopMessage = error.localizedDescription
        }
    }

    func refreshGuest() {
        guard linuxConnected, !terminalBusy else { return }
        terminalBusy = true
        Task {
            defer { terminalBusy = false }
            do {
                applyLinux(try await guest.run("", cwd: state.cwd))
                persist()
            } catch {
                await reportLinuxError(error)
            }
        }
    }

    // MARK: Vorwurf

    public var selectedSuspectID: String? {
        get { engine.state.selectedSuspectID }
        set {
            engine.setSelectedSuspect(newValue)
            persist()
        }
    }

    public var selectedEvidenceIDs: Set<String> {
        get { engine.state.selectedEvidenceIDs }
        set {
            engine.setSelectedEvidenceIDs(newValue)
            persist()
        }
    }

    public func toggleEvidence(_ id: String) {
        engine.toggleEvidence(id)
        persist()
    }

    func submitFinale() async -> String {
        guard episode.id == 7, !terminalBusy else { return "Warte auf Linux." }
        terminalBusy = true
        defer { terminalBusy = false }
        do {
            try await connectLinux()
            applyLinux(try await guest.run("", cwd: state.cwd))
            engine.setSelectedSuspect("timo")
            return submitAccusation().message
        } catch {
            await reportLinuxError(error)
            engine.setFeedback(linuxMessage)
            persist()
            return linuxMessage
        }
    }

    /// Prüft den Vorwurf und schreibt das Ergebnis in den Zustand.
    @discardableResult
    public func submitAccusation() -> AccusationResult {
        let result = engine.evaluateAccusation(suspectID: selectedSuspectID, evidenceIDs: selectedEvidenceIDs)
        engine.setFeedback(result.message)
        if case .accepted = result.outcome {
            engine.markSolved()
            engine.setPage(.briefing)
        }
        persist()
        return result
    }

    // MARK: Zurücksetzen

    /// Setzt den Fortschritt zurück. Wird nur nach bestätigter Rückfrage
    /// aufgerufen; vorher wird ein Backup des bisherigen Spielstands angelegt.
    public func resetProgress() {
        guard !terminalBusy else { return }
        terminalBusy = true
        Task {
            defer { terminalBusy = false }
            do {
                try await guest.stop()
                resetTerminal()
                linuxConnected = false
                desktopReady = false
                desktopMessage = nil
                linuxMessage = "Linux bereit zum Start"
                let fresh = GameEngine(state: GameState(episode: episode))
                var resetStore = store
                try guest.withArchivedDisk {
                    try resetStore.liftWriteProtection()
                    try resetStore.save(fresh.state)
                }
                store = resetStore
                engine = fresh
                loadWarning = nil
                statusMessage = "Spielstand zurückgesetzt."
            } catch {
                statusMessage = "Zurücksetzen fehlgeschlagen: \(error.localizedDescription)"
            }
        }
    }

    // MARK: Persistenz

    public func persist() {
        do {
            try store.save(engine.state)
            statusMessage = nil
        } catch GameStore.StoreError.writeProtected {
            // Die defekte Datei bleibt unverändert; der Nutzer muss das
            // Zurücksetzen bewusst bestätigen.
            statusMessage = "Der defekte Spielstand wird nicht überschrieben. Bestätige „Zurücksetzen“, um neu zu beginnen."
        } catch {
            // Fehler nicht verschlucken: der Nutzer muss es sehen.
            statusMessage = "Speichern fehlgeschlagen: \(error.localizedDescription)"
        }
    }
}
