import Foundation

/// Persistenz des Spielstands als Codable JSON.
///
/// Ablage: `~/Library/Application Support/StaffelZwei/` – überschreibbar per
/// Umgebungsvariable `APP_STORE` (für isolierte Tests und Screenshots).
///
/// Pfadpriorität: ein explizit übergebener Pfad schlägt `APP_STORE`, das
/// wiederum den Standardpfad schlägt. Tests benutzen deshalb immer ihr
/// eigenes temporäres Verzeichnis und können niemals echte Nutzerdaten
/// treffen.
public struct GameStore: Sendable {
    public enum LoadResult: Sendable, Equatable {
        case loaded(GameState)
        case fresh
        /// Die Datei existiert, ist aber nicht lesbar. Sie bleibt unangetastet.
        case corrupt(reason: String)
    }

    public enum StoreError: Error, LocalizedError, Equatable {
        /// Der geladene Spielstand ist defekt und wird nicht still überschrieben.
        case writeProtected
        case saveFailed(String)

        public var errorDescription: String? {
            switch self {
            case .writeProtected:
                return "Der Spielstand ist defekt und wird nicht automatisch überschrieben."
            case .saveFailed(let reason):
                return "Speichern fehlgeschlagen: \(reason)"
            }
        }
    }

    public let directory: URL
    public let fileURL: URL
    /// true, solange eine defekte Datei ohne ausdrückliche Entscheidung des
    /// Nutzers nicht überschrieben werden darf.
    public private(set) var isWriteProtected: Bool = false

    /// Erzeugt einen Store.
    ///
    /// - Parameter directory: Zielverzeichnis. Hat Vorrang vor `APP_STORE`
    ///   und vor dem Standardpfad im Benutzerverzeichnis.
    public init(directory: URL? = nil) {
        let base: URL
        if let directory {
            base = directory
        } else if let override = ProcessInfo.processInfo.environment["APP_STORE"],
                  !override.isEmpty {
            base = URL(fileURLWithPath: (override as NSString).expandingTildeInPath)
        } else {
            base = FileManager.default
                .homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Application Support/StaffelZwei", isDirectory: true)
        }
        self.directory = base
        self.fileURL = base.appendingPathComponent("spielstand.json")
    }

    public static func defaultDirectory() -> URL {
        GameStore().directory
    }

    /// Lädt den Spielstand. Ein defekter Store bleibt unangetastet.
    public func load() -> LoadResult {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return .fresh }
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let state = try decoder.decode(GameState.self, from: data)
            return .loaded(state)
        } catch {
            return .corrupt(reason: (error as NSError).localizedDescription)
        }
    }

    /// Sperrt das Überschreiben, bis der Nutzer ausdrücklich entscheidet.
    ///
    /// Wird nach einem Lesefehler gesetzt: eine defekte Datei bleibt dann
    /// byte-identisch erhalten, bis der Nutzer das Zurücksetzen bestätigt.
    public mutating func protectFromOverwrite() {
        isWriteProtected = true
    }

    /// Hebt den Schreibschutz auf.
    ///
    /// Vorher wird ein Backup der vorhandenen Datei angelegt, damit ein
    /// defekter Spielstand nicht verloren geht. Gibt den Backup-Pfad zurück
    /// (nil, wenn es keine Datei gab).
    @discardableResult
    public mutating func liftWriteProtection() throws -> URL? {
        defer { isWriteProtected = false }
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        return try makeBackup()
    }

    /// Schreibt den Spielstand atomar: erst in eine Tempdatei, dann umbenannt.
    @discardableResult
    public func save(_ state: GameState) throws -> URL {
        if isWriteProtected {
            throw StoreError.writeProtected
        }
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(state)

            let tempURL = directory.appendingPathComponent("spielstand.json.tmp")
            try data.write(to: tempURL, options: .atomic)
            // Ersetzt die bestehende Datei nur, wenn das Schreiben geklappt hat.
            if FileManager.default.fileExists(atPath: fileURL.path) {
                _ = try FileManager.default.replaceItemAt(fileURL, withItemAt: tempURL)
            } else {
                try FileManager.default.moveItem(at: tempURL, to: fileURL)
            }
            return fileURL
        } catch let error as StoreError {
            throw error
        } catch {
            throw StoreError.saveFailed(error.localizedDescription)
        }
    }

    /// Löscht ausschliesslich die eigenen Daten des Spiels.
    ///
    /// Vor dem Löschen wird ein Backup mit Zeitstempel abgelegt, damit ein
    /// Fehler nicht unwiderruflich ist.
    @discardableResult
    public func reset() throws -> URL {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return fileURL
        }
        let backup = try makeBackup()
        try FileManager.default.removeItem(at: fileURL)
        return backup
    }

    /// Legt eine Kopie der aktuellen Spielstanddatei neben dem Original ab.
    private func makeBackup() throws -> URL {
        let stamp = ISO8601DateFormatter().string(from: Date())
            .replacingOccurrences(of: ":", with: "-")
        var target = directory.appendingPathComponent("spielstand.geloescht-\(stamp).json")
        var counter = 1
        while FileManager.default.fileExists(atPath: target.path) {
            target = directory.appendingPathComponent("spielstand.geloescht-\(stamp)-\(counter).json")
            counter += 1
        }
        try FileManager.default.copyItem(at: fileURL, to: target)
        return target
    }
}
