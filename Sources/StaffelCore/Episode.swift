import Foundation

// MARK: - Episodendaten

/// Eine Spur (Beweisrichtung) einer Episode.
public struct Track: Identifiable, Codable, Sendable, Equatable {
    public let id: String
    public let title: String
    public let summary: String

    public init(id: String, title: String, summary: String) {
        self.id = id
        self.title = title
        self.summary = summary
    }
}

/// Erwarteter Beleg: Dateiname, Spur und Validierungsregel.
public struct EvidenceSpec: Identifiable, Codable, Sendable, Equatable {
    public let id: String
    public let trackID: String
    public let fileName: String
    public let title: String
    /// Textfragmente, die alle im gespeicherten Inhalt vorkommen müssen.
    public let requiredFragments: [String]
    /// Textfragmente, die nicht vorkommen dürfen.
    public let forbiddenFragments: [String]
    public let hint: String

    public init(id: String, trackID: String, fileName: String, title: String,
                requiredFragments: [String], forbiddenFragments: [String] = [], hint: String) {
        self.id = id
        self.trackID = trackID
        self.fileName = fileName
        self.title = title
        self.requiredFragments = requiredFragments
        self.forbiddenFragments = forbiddenFragments
        self.hint = hint
    }

    /// Prüft, ob ein gespeicherter Inhalt ein gültiger Beleg ist.
    public func validate(_ content: String) -> Bool {
        let lowered = content.lowercased()
        for fragment in requiredFragments where !lowered.contains(fragment.lowercased()) {
            return false
        }
        for fragment in forbiddenFragments where lowered.contains(fragment.lowercased()) {
            return false
        }
        return true
    }
}

/// Eine verdächtige Person im Fall.
public struct Suspect: Identifiable, Codable, Sendable, Equatable {
    public let id: String
    public let name: String
    public let role: String
    public let detail: String
    public let systemImage: String

    public init(id: String, name: String, role: String, detail: String, systemImage: String) {
        self.id = id
        self.name = name
        self.role = role
        self.detail = detail
        self.systemImage = systemImage
    }
}

/// Eine spielbare Ermittlungsakte mit Spuren und Verdächtigen.
public struct Episode: Identifiable, Codable, Sendable, Equatable {
    public let id: Int
    public let key: String
    public let title: String
    public let caseTitle: String
    public let organization: String
    public let account: String
    public let briefing: String
    public let tracks: [Track]
    public let evidenceSpecs: [EvidenceSpec]
    public let suspects: [Suspect]
    /// ID des Täters.
    public let culpritID: String
    public let steps: [EpisodeStep]
    /// true, wenn die Episode spielbar ist.
    public let playable: Bool

    public init(id: Int, key: String, title: String, caseTitle: String, organization: String,
                account: String, briefing: String, tracks: [Track], evidenceSpecs: [EvidenceSpec],
                suspects: [Suspect], culpritID: String, steps: [EpisodeStep], playable: Bool) {
        self.id = id
        self.key = key
        self.title = title
        self.caseTitle = caseTitle
        self.organization = organization
        self.account = account
        self.briefing = briefing
        self.tracks = tracks
        self.evidenceSpecs = evidenceSpecs
        self.suspects = suspects
        self.culpritID = culpritID
        self.steps = steps
        self.playable = playable
    }
}

/// Ein Arbeitsschritt einer Episode.
public struct EpisodeStep: Identifiable, Codable, Sendable, Equatable {
    public let id: String
    public let trackID: String
    public let title: String
    public let detail: String
    public let command: String?

    public init(id: String, trackID: String, title: String, detail: String, command: String? = nil) {
        self.id = id
        self.trackID = trackID
        self.title = title
        self.detail = detail
        self.command = command
    }
}

// MARK: - Inhalte

public enum EpisodeCatalog {
    /// Die Originaldaten der Rechenwerk Ostwind GmbH.
    public static let originalCSV = """
    datum,name,betrag
    2026-04-13,Timo,5.00
    2026-04-14,Nadia,5.00
    2026-04-15,Timo,2.50
    2026-04-16,Nadia,7.00
    2026-04-17,Timo,3.50
    """

    /// Die nachts veränderte Fassung: Betrag 0.50 statt 2.50.
    public static let changedCSV = """
    datum,name,betrag
    2026-04-13,Timo,5.00
    2026-04-14,Nadia,5.00
    2026-04-15,Timo,0.50
    2026-04-16,Nadia,7.00
    2026-04-17,Timo,3.50
    """

    public static let uebungPath = "/srv/rechenwerk/uebung"
    public static let csvPath = "/srv/rechenwerk/uebung/kaffeekasse.csv"
    public static let bakPath = "/srv/rechenwerk/uebung/kaffeekasse.bak"
    public static let belegePath = "/home/azubi/belege"

    /// Datum/Zeit der Änderung an der CSV-Datei: 2026-04-17 03:12:00 UTC.
    public static let csvModified = utcDate(2026, 4, 17, 3, 12, 0)
    /// Datum/Zeit der Sicherung: 2026-04-16 22:05:00 UTC.
    public static let bakModified = utcDate(2026, 4, 16, 22, 5, 0)

    /// Erzeugt ein UTC-Datum. Ohne diese Hilfsfunktion wäre der Epoch-Wert
    /// fehleranfällig; so steht das Datum exakt so im Code wie in der Vorgabe.
    private static func utcDate(_ year: Int, _ month: Int, _ day: Int,
                                _ hour: Int, _ minute: Int, _ second: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        components.second = second
        return calendar.date(from: components) ?? Date(timeIntervalSince1970: 0)
    }

    public static let tracks: [Track] = [
        Track(id: "akte", title: "Akte", summary: "Metadaten sichern: Besitzer, Rechte und Datum beider Dateien."),
        Track(id: "inhalt", title: "Inhalt", summary: "Inhalt sichern: geänderte Zeile und ihr Original festhalten."),
    ]

    public static let suspects: [Suspect] = [
        Suspect(id: "timo", name: "Timo Kessler", role: "Systemadministrator",
                detail: "Trinkt den meisten Kaffee.", systemImage: "person.crop.circle"),
        Suspect(id: "nadia", name: "Nadia Brem", role: "Datenbankverwaltung",
                detail: "Führt die Kaffeekasse.", systemImage: "person.crop.circle"),
        Suspect(id: "kaffee", name: "Kaffeeautomat", role: "Dienstkonto kaffee",
                detail: "Gleicht nachts die Kasse ab.", systemImage: "cup.and.saucer"),
    ]

    public static let evidenceSpecs: [EvidenceSpec] = [
        EvidenceSpec(
            id: "kasse-meta",
            trackID: "akte",
            fileName: "kasse-meta.txt",
            title: "Metadaten der Kaffeekasse",
            requiredFragments: ["kaffeekasse.csv", "kaffeekasse.bak", "kaffee", "2026-04-17", "03:12"],
            forbiddenFragments: [],
            hint: "Mit `ls -l /srv/rechenwerk/uebung/` siehst du Besitzer, Rechte und Datum beider Dateien."
        ),
        EvidenceSpec(
            id: "kasse-zeilen",
            trackID: "inhalt",
            fileName: "kasse-zeilen.txt",
            title: "Zeilen um den 15. April",
            requiredFragments: ["2026-04-15,Timo,2.50", "2026-04-15,Timo,0.50"],
            forbiddenFragments: [],
            hint: "Sichere die geänderte Zeile aus der CSV und ihr Original aus der BAK."
        ),
    ]

    public static let episode0Steps: [EpisodeStep] = [
        EpisodeStep(id: "meta-lesen", trackID: "akte",
                    title: "Besitzer, Rechte und Datum ablesen",
                    detail: "In /srv/rechenwerk/uebung/ liegen die Kaffeekasse-Liste kaffeekasse.csv und ihre Sicherung kaffeekasse.bak vom Abend davor.",
                    command: "ls -l /srv/rechenwerk/uebung/"),
        EpisodeStep(id: "meta-sichern", trackID: "akte",
                    title: "Metadaten in einem Beleg sichern",
                    detail: "Ein Beleg ist die echte Ausgabe eines Befehls, in eine Textdatei in ~/belege/ umgeleitet. Abgetippter Text zählt nicht.",
                    command: "ls -l /srv/rechenwerk/uebung/ > ~/belege/kasse-meta.txt"),
        EpisodeStep(id: "zeilen-sichern", trackID: "inhalt",
                    title: "Geänderte Zeile und ihr Original sichern",
                    detail: "In der Liste wurde nachts ein Betrag verändert. Sichere beide Fassungen der Zeile vom 15. April.",
                    command: "grep 2026-04-15 /srv/rechenwerk/uebung/kaffeekasse.csv > ~/belege/kasse-zeilen.txt"),
        EpisodeStep(id: "zeilen-original", trackID: "inhalt",
                    title: "Original aus der Sicherung anhängen",
                    detail: "Das Original der Zeile steht in der BAK. Hänge es an denselben Beleg an.",
                    command: "grep 2026-04-15 /srv/rechenwerk/uebung/kaffeekasse.bak >> ~/belege/kasse-zeilen.txt"),
        EpisodeStep(id: "reparatur", trackID: "inhalt",
                    title: "Liste aus der Sicherung wiederherstellen",
                    detail: "Erst sichern, dann reparieren. Wer vorher repariert, löscht den Beweis.",
                    command: "cp /srv/rechenwerk/uebung/kaffeekasse.bak /srv/rechenwerk/uebung/kaffeekasse.csv"),
        EpisodeStep(id: "vorwurf", trackID: "akte",
                    title: "Vorwurf erheben",
                    detail: "Wähle den Verdächtigen und belege ihn mit zwei anerkannten Belegen aus beiden Spuren.",
                    command: nil),
    ]

    public static let episode0 = Episode(
        id: 0,
        key: "probelauf",
        title: "Probelauf",
        caseTitle: "Die Kaffeekasse",
        organization: "Rechenwerk Ostwind GmbH",
        account: "azubi",
        briefing: """
        Erster Einsatztag bei der Rechenwerk Ostwind GmbH. Bevor es ernst wird, ein Probelauf. Hier kann nichts kaputtgehen. Du bist das Testkonto azubi.

        In /srv/rechenwerk/uebung/ liegen die Kaffeekasse-Liste kaffeekasse.csv und ihre Sicherung kaffeekasse.bak vom Abend davor. In der Liste wurde nachts ein Betrag verändert. Wer war es?

        Die Regel für jeden Fall: erst Belege sichern, dann reparieren. Wer vorher repariert, löscht den Beweis.
        """,
        tracks: tracks,
        evidenceSpecs: evidenceSpecs,
        suspects: suspects,
        culpritID: "kaffee",
        steps: episode0Steps,
        playable: true
    )

    public static let laterEpisodes = BrowserMission.all.map(\.episode)

    public static var all: [Episode] { [episode0] + laterEpisodes }

    public static func episode(id: Int) -> Episode {
        all.first { $0.id == id } ?? episode0
    }

    /// Erzeugt die anfängliche virtuelle Dateiwelt.
    public static func makeInitialFS() -> VirtualFS {
        var files: [String: VFile] = [:]
        files[csvPath] = VFile(
            content: changedCSV,
            meta: FileMeta(owner: "kaffee", group: "azubi", permissions: 0o664, modified: csvModified)
        )
        files[bakPath] = VFile(
            content: originalCSV,
            meta: FileMeta(owner: "root", group: "root", permissions: 0o644, modified: bakModified)
        )

        let directories: Set<String> = [
            "/", "/home", "/home/azubi", "/home/azubi/belege",
            "/srv", "/srv/rechenwerk", "/srv/rechenwerk/uebung",
        ]

        return VirtualFS(files: files, directories: directories)
    }
}
