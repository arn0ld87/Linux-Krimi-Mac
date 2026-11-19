import Foundation

// MARK: - Spielzustand

/// Ein anerkannter Beleg (eine gespeicherte, geprüfte Ausgabe).
public struct Evidence: Identifiable, Codable, Sendable, Equatable {
    public let id: String
    public let specID: String
    public let trackID: String
    public let title: String
    public let fileName: String
    public let content: String
    public let validated: Bool
    public let validationHint: String?

    public init(specID: String, trackID: String, title: String, fileName: String,
                content: String, validated: Bool, validationHint: String?) {
        self.id = specID
        self.specID = specID
        self.trackID = trackID
        self.title = title
        self.fileName = fileName
        self.content = content
        self.validated = validated
        self.validationHint = validationHint
    }
}

/// Eine Zeile im Terminal-Verlauf.
public struct TranscriptEntry: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    public let kind: Kind
    public let text: String

    public enum Kind: String, Codable, Sendable {
        case input
        case output
        case error
        case system
    }

    public init(id: UUID = UUID(), kind: Kind, text: String) {
        self.id = id
        self.kind = kind
        self.text = text
    }
}

/// Die gewählte Seite der App (für die Persistenz).
public enum AppPage: String, Codable, Sendable, CaseIterable {
    case briefing
    case terminal
    case aktenwand
    case vorwurf
    case help
    case desktop
}

/// Vollständiger Spielzustand. Codierbar für die JSON-Persistenz.
public struct GameState: Codable, Sendable, Equatable {
    public var episodeID: Int
    public var fs: VirtualFS
    public var cwd: String
    public var transcript: [TranscriptEntry]
    public var evidences: [Evidence]
    public var selectedSuspectID: String?
    public var selectedEvidenceIDs: Set<String>
    /// true, wenn die CSV wieder dem Original entspricht.
    public var repaired: Bool
    public var solved: Bool
    public var page: AppPage
    public var lastAccusationFeedback: String?
    public var linuxChecks: Set<String>?
    public var acceptedAnswers: Set<String>?

    public init(episode: Episode = EpisodeCatalog.episode0) {
        self.episodeID = episode.id
        self.fs = episode.id == 0 ? EpisodeCatalog.makeInitialFS() : VirtualFS()
        self.cwd = VPath.home
        self.transcript = [
            TranscriptEntry(kind: .system, text: "Die Befehle laufen in einer lokalen Alpine-Linux-VM.")
        ]
        self.evidences = []
        self.selectedSuspectID = nil
        self.selectedEvidenceIDs = []
        self.repaired = false
        self.solved = false
        self.page = .briefing
        self.lastAccusationFeedback = nil
    }

    /// Maximale Länge des Verlaufs, damit die Datei nicht unbegrenzt wächst.
    public static let transcriptLimit = 200

    public var episode: Episode { EpisodeCatalog.episode(id: episodeID) }

    /// Erkannte Belege neu bewerten (z. B. nach einer Änderung an der Dateiwelt).
    public mutating func refreshEvidences() {
        var updated: [Evidence] = []
        for spec in episode.evidenceSpecs {
            let path = VPath.home + "/belege/" + spec.fileName
            guard let file = fs.file(at: path) else { continue }
            let valid = episodeID == 0 ? spec.validate(file.content) : linuxChecks?.contains(spec.id) == true
            updated.append(Evidence(
                specID: spec.id,
                trackID: spec.trackID,
                title: spec.title,
                fileName: spec.fileName,
                content: file.content,
                validated: valid,
                validationHint: valid ? nil : spec.hint
            ))
        }
        evidences = updated
        // Auswahl auf weiterhin vorhandene Belege beschränken.
        selectedEvidenceIDs = selectedEvidenceIDs.filter { id in updated.contains { $0.id == id } }
    }

    /// Belege, die validiert und ausgewählt sind, gruppiert nach Spur.
    public var validatedSelectedEvidence: [Evidence] {
        evidences.filter { $0.validated && selectedEvidenceIDs.contains($0.id) }
    }

    /// true, wenn mindestens ein valider Beleg aus jeder Spur ausgewählt ist.
    public var hasEvidenceFromEveryTrack: Bool {
        let trackIDs = Set(validatedSelectedEvidence.map(\.trackID))
        return episode.tracks.allSatisfy { trackIDs.contains($0.id) }
    }

    /// Fortschritt: erfüllte Spuren (alle Belege einer Spur validiert).
    public var completedTracks: Int {
        if episodeID != 0 {
            return episode.tracks.filter { track in
                episode.steps.filter { $0.trackID == track.id }.allSatisfy { isStepComplete($0.id) }
            }.count
        }
        return episode.tracks.filter { track in
            episode.evidenceSpecs
                .filter { $0.trackID == track.id }
                .allSatisfy { spec in evidences.contains { $0.specID == spec.id && $0.validated } }
        }.count
    }

    /// Prüft, ob die CSV wieder dem Original entspricht.
    public var isCSVRepaired: Bool {
        guard let csv = fs.file(at: EpisodeCatalog.csvPath) else { return false }
        return csv.content == EpisodeCatalog.originalCSV
    }

    public func isStepComplete(_ id: String) -> Bool {
        linuxChecks?.contains(id) == true || acceptedAnswers?.contains(id) == true
    }
}

// MARK: - Vorwurf

/// Ergebnis einer Vorwurfsprüfung.
public struct AccusationResult: Sendable, Equatable {
    public enum Outcome: Sendable, Equatable {
        case accepted
        case wrongSuspect(culpritName: String)
        case missingEvidence(reason: String)
        case notRepaired
    }

    public let outcome: Outcome
    public let message: String

    public init(outcome: Outcome, message: String) {
        self.outcome = outcome
        self.message = message
    }
}

// MARK: - Engine

/// Fachlogik des Spiels: Befehle ausführen, Belege bewerten, Vorwurf prüfen.
public struct GameEngine {
    public private(set) var state: GameState

    public init(state: GameState = GameState()) {
        self.state = state
    }

    /// Führt einen Terminal-Befehl aus und aktualisiert den Zustand.
    ///
    /// Ein Fehler verändert den Dateisystemzustand nicht.
    @discardableResult
    public mutating func run(_ input: String) -> ShellResult {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return ShellResult(output: "", isError: false)
        }

        state.transcript.append(TranscriptEntry(kind: .input, text: trimmed))

        var shell = Shell(fs: state.fs, cwd: state.cwd)
        let result = shell.run(trimmed)
        state.fs = shell.fs
        state.cwd = shell.cwd
        appendResult(result)
        refreshProgress()
        return result
    }

    /// Projects the mission files from the Linux guest into the existing case state.
    public mutating func syncLinux(cwd: String, files: [String: String], checks: Set<String> = []) {
        state.cwd = cwd
        state.linuxChecks = checks
        if state.transcript.first?.text == "Lokale Übungssimulation – keine Befehle auf deinem Mac." {
            state.transcript[0] = TranscriptEntry(
                kind: .system, text: "Die Befehle laufen in einer lokalen Alpine-Linux-VM."
            )
        }
        for (key, path) in linuxMissionPaths {
            if let content = files[key] {
                let meta = state.fs.files[path]?.meta ?? FileMeta(
                    owner: "azubi", group: "azubi", permissions: 0o664, modified: Date()
                )
                state.fs.setFile(VFile(content: content, meta: meta), at: path)
            } else {
                state.fs.files.removeValue(forKey: path)
            }
        }
        refreshProgress()
    }

    public var linuxSeed: [String: String] {
        guard state.episodeID == 0 else { return [:] }
        var seed = ["backup": EpisodeCatalog.originalCSV,
                    "csv": state.fs.file(at: EpisodeCatalog.csvPath)?.content ?? EpisodeCatalog.changedCSV]
        for (key, path) in linuxMissionPaths where key != "csv" {
            if let content = state.fs.file(at: path)?.content, content.utf8.count <= 64 * 1024 {
                seed[key] = content
            }
        }
        return seed
    }

    public mutating func recordLinuxCommand(_ input: String, output: String, failed: Bool) {
        state.transcript.append(TranscriptEntry(kind: .input, text: input))
        appendResult(ShellResult(output: output, isError: failed))
    }

    public mutating func clearTerminal() {
        state.transcript.removeAll()
    }

    public mutating func markAnswer(_ id: String) {
        var answers = state.acceptedAnswers ?? []
        answers.insert(id)
        state.acceptedAnswers = answers
    }

    private var linuxMissionPaths: [String: String] {
        if state.episodeID == 0 {
            return ["csv": EpisodeCatalog.csvPath, "meta": EpisodeCatalog.belegePath + "/kasse-meta.txt",
                    "lines": EpisodeCatalog.belegePath + "/kasse-zeilen.txt"]
        }
        return Dictionary(uniqueKeysWithValues: state.episode.evidenceSpecs.map {
            ($0.id, EpisodeCatalog.belegePath + "/" + $0.fileName)
        })
    }

    private mutating func appendResult(_ result: ShellResult) {
        if result.isError {
            state.transcript.append(TranscriptEntry(kind: .error, text: result.output))
        } else if !result.output.isEmpty {
            state.transcript.append(TranscriptEntry(kind: .output, text: result.output))
        }

        if state.transcript.count > GameState.transcriptLimit {
            state.transcript.removeFirst(state.transcript.count - GameState.transcriptLimit)
        }
    }

    private mutating func refreshProgress() {
        state.refreshEvidences()
        state.repaired = BrowserMission.forEpisode(state.episodeID)?.repairs.allSatisfy(state.isStepComplete)
            ?? state.isCSVRepaired
    }

    /// Prüft den Vorwurf: Verdächtiger plus explizit ausgewählte Belege aus beiden Spuren.
    public func evaluateAccusation(suspectID: String?, evidenceIDs: Set<String>) -> AccusationResult {
        guard let suspectID else {
            return AccusationResult(
                outcome: .missingEvidence(reason: "Kein Verdächtiger gewählt."),
                message: "Wähle zuerst einen Verdächtigen."
            )
        }

        let selected = state.evidences.filter { evidenceIDs.contains($0.id) }
        let validated = selected.filter(\.validated)

        let mission = BrowserMission.forEpisode(state.episodeID)
        if validated.count < (mission?.minimumEvidence ?? 2) {
            return AccusationResult(
                outcome: .missingEvidence(reason: "Mindestens zwei anerkannte Belege sind nötig."),
                message: mission?.insufficientEvidence
                    ?? "Es fehlen anerkannte Belege. Du brauchst mindestens zwei gültige Belege – und zwar aus beiden Spuren."
            )
        }
        let trackIDs = Set(validated.map(\.trackID))
        let missingTracks = state.episode.tracks.filter { !trackIDs.contains($0.id) }
        if !missingTracks.isEmpty {
            let names = missingTracks.map(\.title).joined(separator: " und ")
            return AccusationResult(
                outcome: .missingEvidence(reason: "Beleg aus der Spur \(names) fehlt."),
                message: "Deine Belege stammen nur aus einer Spur. Es fehlt ein Beleg aus \(names)."
            )
        }
        if let mission {
            let pending = mission.episode.steps.filter { !state.isStepComplete($0.id) }
            if !pending.isEmpty {
                return AccusationResult(outcome: .notRepaired,
                                        message: "Noch offen: " + pending.map(\.title).joined(separator: ", "))
            }
        } else if !state.isCSVRepaired {
            return AccusationResult(
                outcome: .notRepaired,
                message: "Die Kaffeekasse ist noch nicht wiederhergestellt. Repariere zuerst die Liste aus der Sicherung."
            )
        }

        guard let suspect = state.episode.suspects.first(where: { $0.id == suspectID }) else {
            return AccusationResult(
                outcome: .missingEvidence(reason: "Unbekannter Verdächtiger."),
                message: "Dieser Verdächtige ist nicht Teil des Falls."
            )
        }

        if suspectID == state.episode.culpritID {
            return AccusationResult(
                outcome: .accepted,
                message: mission?.resolution ?? "Probelauf bestanden. Jetzt wird es ernst."
            )
        }

        let culprit = state.episode.suspects.first { $0.id == state.episode.culpritID }
        return AccusationResult(
            outcome: .wrongSuspect(culpritName: culprit?.name ?? "kaffee"),
            message: mission?.wrongSuspect
                ?? "\(suspect.name) war es nicht. Die Spuren sprechen für ein anderes Konto – prüfe Besitzer und Dienstkonto."
        )
    }

    /// Setzt die ausgewählte Seite.
    public mutating func setPage(_ page: AppPage) {
        state.page = page
    }

    /// Wählt den Verdächtigen (nil hebt die Auswahl auf).
    public mutating func setSelectedSuspect(_ id: String?) {
        state.selectedSuspectID = id
    }

    /// Setzt die Auswahl der Belege.
    public mutating func setSelectedEvidenceIDs(_ ids: Set<String>) {
        state.selectedEvidenceIDs = ids
    }

    /// Schaltet einen Beleg in der Auswahl um.
    public mutating func toggleEvidence(_ id: String) {
        if state.selectedEvidenceIDs.contains(id) {
            state.selectedEvidenceIDs.remove(id)
        } else {
            state.selectedEvidenceIDs.insert(id)
        }
    }

    /// Speichert die Rückmeldung des letzten Vorwurfs.
    public mutating func setFeedback(_ message: String?) {
        state.lastAccusationFeedback = message
    }

    /// Markiert den Fall als gelöst.
    public mutating func markSolved() {
        state.solved = true
    }
}
