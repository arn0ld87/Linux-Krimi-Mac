import Foundation
import Testing

@testable import StaffelCore

// MARK: - Fixtures

private func makeEngine() -> GameEngine {
    GameEngine()
}

private let csv = EpisodeCatalog.csvPath
private let bak = EpisodeCatalog.bakPath

// MARK: - Ausgangslage

@Test("CSV und BAK starten unterschiedlich")
func initialFilesDiffer() {
    let engine = makeEngine()
    let csvFile = engine.state.fs.file(at: csv)
    let bakFile = engine.state.fs.file(at: bak)
    #expect(csvFile != nil)
    #expect(bakFile != nil)
    #expect(csvFile?.content != bakFile?.content)
    #expect(csvFile?.content.contains("2026-04-15,Timo,0.50") == true)
    #expect(bakFile?.content.contains("2026-04-15,Timo,2.50") == true)
}

@Test("Metadaten entsprechen den Vorgaben")
func metadataMatchesSpec() {
    let engine = makeEngine()
    let csvMeta = engine.state.fs.file(at: csv)?.meta
    #expect(csvMeta?.owner == "kaffee")
    #expect(csvMeta?.group == "azubi")
    #expect(csvMeta?.permissions == 0o664)
    #expect(csvMeta?.modified.formattedStampUTC == "2026-04-17 03:12")

    let bakMeta = engine.state.fs.file(at: bak)?.meta
    #expect(bakMeta?.owner == "root")
    #expect(bakMeta?.group == "root")
    #expect(bakMeta?.permissions == 0o644)
    #expect(bakMeta?.modified.formattedStampUTC == "2026-04-16 22:05")
}

// MARK: - Shell

@Test("pwd liefert das Home-Verzeichnis")
func testPwd() {
    var engine = makeEngine()
    let result = engine.run("pwd")
    #expect(!result.isError)
    #expect(result.output.contains("/home/azubi"))
}

@Test("Absolute, relative und ~-Pfade lösen gleich auf")
func testPathForms() {
    var engine = makeEngine()
    #expect(engine.run("cat /srv/rechenwerk/uebung/kaffeekasse.csv").output.contains("0.50"))
    #expect(engine.run("cd /srv/rechenwerk/uebung").isError == false)
    #expect(engine.state.cwd == "/srv/rechenwerk/uebung")
    #expect(engine.run("cat kaffeekasse.csv").output.contains("0.50"))
    #expect(engine.run("cd ~").isError == false)
    #expect(engine.state.cwd == "/home/azubi")
    #expect(engine.run("cat ~/belege/nichtda.txt").isError)
}

@Test("cd .. und . funktionieren")
func testDotPaths() {
    var engine = makeEngine()
    engine.run("cd /srv/rechenwerk/uebung")
    #expect(engine.state.cwd == "/srv/rechenwerk/uebung")
    engine.run("cd ..")
    #expect(engine.state.cwd == "/srv/rechenwerk")
    engine.run("cd .")
    #expect(engine.state.cwd == "/srv/rechenwerk")
}

@Test("ls -l zeigt Besitzer, Rechte und Datum")
func testLsLong() {
    var engine = makeEngine()
    let result = engine.run("ls -l /srv/rechenwerk/uebung/")
    #expect(result.isError == false)
    #expect(result.output.contains("kaffeekasse.csv"))
    #expect(result.output.contains("kaffeekasse.bak"))
    #expect(result.output.contains("kaffee"))
    #expect(result.output.contains("2026-04-17 03:12"))
    #expect(result.output.contains("root"))
    #expect(result.output.contains("2026-04-16 22:05"))
}

@Test("stat zeigt Besitzer und Rechte")
func testStat() {
    var engine = makeEngine()
    let result = engine.run("stat /srv/rechenwerk/uebung/kaffeekasse.csv")
    #expect(result.isError == false)
    #expect(result.output.contains("kaffee"))
    #expect(result.output.contains("0664"))
    #expect(result.output.contains("2026-04-17 03:12:00"))
}

@Test("grep findet Zeilen in einer Datei")
func testGrep() {
    var engine = makeEngine()
    let result = engine.run("grep 2026-04-15 /srv/rechenwerk/uebung/kaffeekasse.csv")
    #expect(result.isError == false)
    #expect(result.output.contains("2026-04-15,Timo,0.50"))
}

@Test("Quotes werden korrekt geparst")
func testQuoting() {
    var engine = makeEngine()
    engine.run("mkdir -p ~/belege")
    let result = engine.run("cat \"/srv/rechenwerk/uebung/kaffeekasse.csv\"")
    #expect(result.isError == false)
    #expect(result.output.contains("datum,name,betrag"))

    let single = engine.run("grep '2026-04-15,Timo,0.50' /srv/rechenwerk/uebung/kaffeekasse.csv")
    #expect(single.isError == false)
    #expect(single.output.contains("0.50"))
}

@Test("Mehrere Dateien in einem cat")
func testMultipleFiles() {
    var engine = makeEngine()
    let result = engine.run("cat /srv/rechenwerk/uebung/kaffeekasse.bak /srv/rechenwerk/uebung/kaffeekasse.csv")
    #expect(result.isError == false)
    #expect(result.output.contains("2.50"))
    #expect(result.output.contains("0.50"))
}

@Test("> ersetzt, >> haengt an")
func testRedirection() {
    var engine = makeEngine()
    engine.run("ls -l /srv/rechenwerk/uebung/ > ~/belege/kasse-meta.txt")
    let first = engine.state.fs.file(at: "/home/azubi/belege/kasse-meta.txt")?.content ?? ""
    #expect(first.contains("kaffeekasse.csv"))
    #expect(first.contains("2026-04-17 03:12"))

    engine.run("grep 2026-04-15 /srv/rechenwerk/uebung/kaffeekasse.csv > ~/belege/kasse-zeilen.txt")
    let oneLine = engine.state.fs.file(at: "/home/azubi/belege/kasse-zeilen.txt")?.content ?? ""
    #expect(oneLine.contains("0.50"))
    #expect(oneLine.contains("2.50") == false)

    engine.run("grep 2026-04-15 /srv/rechenwerk/uebung/kaffeekasse.bak >> ~/belege/kasse-zeilen.txt")
    let twoLines = engine.state.fs.file(at: "/home/azubi/belege/kasse-zeilen.txt")?.content ?? ""
    #expect(twoLines.contains("0.50"))
    #expect(twoLines.contains("2.50"))

    // Erneutes > ersetzt den Inhalt vollstaendig.
    engine.run("grep 2026-04-13 /srv/rechenwerk/uebung/kaffeekasse.csv > ~/belege/kasse-zeilen.txt")
    let replaced = engine.state.fs.file(at: "/home/azubi/belege/kasse-zeilen.txt")?.content ?? ""
    #expect(replaced.contains("2026-04-13"))
    #expect(replaced.contains("2.50") == false)
}

@Test("Schreiben ausserhalb von ~/belege wird abgelehnt")
func testWriteOutsideSandbox() {
    var engine = makeEngine()
    let result = engine.run("echo test > /tmp/x.txt")
    #expect(result.isError)
    #expect(engine.state.fs.file(at: "/tmp/x.txt") == nil)
}

@Test("Die Sicherung ist nicht schreibbar")
func testBackupReadOnly() {
    var engine = makeEngine()
    let result = engine.run("cp /srv/rechenwerk/uebung/kaffeekasse.csv /srv/rechenwerk/uebung/kaffeekasse.bak")
    #expect(result.isError)
    #expect(engine.state.fs.file(at: bak)?.content == EpisodeCatalog.originalCSV)
}

@Test("Die Backup-Datei kann auch per Umleitung nicht beschrieben werden")
func testBackupNotWritableViaRedirect() {
    var engine = makeEngine()
    let result = engine.run("ls -l /srv/rechenwerk/uebung/ > /srv/rechenwerk/uebung/kaffeekasse.bak")
    #expect(result.isError)
    #expect(engine.state.fs.file(at: bak)?.content == EpisodeCatalog.originalCSV)
}

@Test("Mac-Pfade existieren nicht")
func testMacPathsDoNotExist() {
    var engine = makeEngine()
    #expect(engine.run("cat /Users/alex/Desktop/secret.txt").isError)
    #expect(engine.run("cat /etc/passwd").isError)
    #expect(engine.run("cat ~/Library/Preferences/x.plist").isError)
}

@Test("Ein fehlerhafter Befehl veraendert nichts")
func testErrorDoesNotChangeState() {
    var engine = makeEngine()
    let before = engine.state.fs
    let cwdBefore = engine.state.cwd
    #expect(engine.run("cd /gibt/es/nicht").isError)
    #expect(engine.run("cat /srv/rechenwerk/uebung/gibtesnicht.csv").isError)
    #expect(engine.run("quatsch").isError)
    #expect(engine.state.fs.files == before.files)
    #expect(engine.state.fs.directories == before.directories)
    #expect(engine.state.cwd == cwdBefore)
}

@Test("Pipes und Command-Substitution werden abgelehnt")
func testUnsupportedSyntax() {
    var engine = makeEngine()
    #expect(engine.run("ls | grep kaffee").isError)
    #expect(engine.run("cat $(ls)").isError)
    #expect(engine.run("ls && pwd").isError)
    #expect(engine.run("ls; pwd").isError)
}

@Test("cd in ein nicht vorhandenes Verzeichnis wird abgelehnt")
func testCdMissingDirectory() {
    var engine = makeEngine()
    let result = engine.run("cd /srv/rechenwerk/quatsch")
    #expect(result.isError)
    #expect(engine.state.cwd == "/home/azubi")
}

@Test("cp ueberschreibt den Inhalt, behält aber die Besitzer-Metadaten")
func testCpKeepsMetadata() {
    var engine = makeEngine()
    #expect(engine.run("cp /srv/rechenwerk/uebung/kaffeekasse.bak /srv/rechenwerk/uebung/kaffeekasse.csv").isError == false)
    let file = engine.state.fs.file(at: csv)
    #expect(file?.content == EpisodeCatalog.originalCSV)
    #expect(file?.meta.owner == "kaffee")
    #expect(file?.meta.group == "azubi")
}

// MARK: - Belege

@Test("Der Metadaten-Beleg wird nach ls -l anerkannt")
func testMetadataEvidence() {
    var engine = makeEngine()
    engine.run("ls -l /srv/rechenwerk/uebung/ > ~/belege/kasse-meta.txt")
    let evidence = engine.state.evidences.first { $0.specID == "kasse-meta" }
    #expect(evidence != nil)
    #expect(evidence?.validated == true)
    #expect(engine.state.completedTracks == 1)
}

@Test("Der Zeilen-Beleg braucht beide Fassungen")
func testRowsEvidence() {
    var engine = makeEngine()
    // Die Spur "Akte" wird zuerst abgeschlossen, damit am Ende beide Spuren
    // fertig sind. Ohne diesen Schritt waere `completedTracks == 2` nicht
    // erreichbar, weil die Spur "Akte" dann gar keinen Beleg haette.
    engine.run("ls -l /srv/rechenwerk/uebung/ > ~/belege/kasse-meta.txt")
    engine.run("grep 2026-04-15 /srv/rechenwerk/uebung/kaffeekasse.csv > ~/belege/kasse-zeilen.txt")
    #expect(engine.state.evidences.first { $0.specID == "kasse-zeilen" }?.validated == false)

    engine.run("grep 2026-04-15 /srv/rechenwerk/uebung/kaffeekasse.bak >> ~/belege/kasse-zeilen.txt")
    #expect(engine.state.evidences.first { $0.specID == "kasse-zeilen" }?.validated == true)
    #expect(engine.state.completedTracks == 2)
}

@Test("Reparatur allein erzeugt keine Belege")
func testRepairDoesNotCreateEvidence() {
    var engine = makeEngine()
    engine.run("cp /srv/rechenwerk/uebung/kaffeekasse.bak /srv/rechenwerk/uebung/kaffeekasse.csv")
    #expect(engine.state.repaired == true)
    #expect(engine.state.evidences.isEmpty)
    #expect(engine.state.completedTracks == 0)
}

@Test("Belege bleiben nach der Reparatur gueltig")
func testEvidenceSurvivesRepair() {
    var engine = makeEngine()
    engine.run("ls -l /srv/rechenwerk/uebung/ > ~/belege/kasse-meta.txt")
    engine.run("grep 2026-04-15 /srv/rechenwerk/uebung/kaffeekasse.csv > ~/belege/kasse-zeilen.txt")
    engine.run("grep 2026-04-15 /srv/rechenwerk/uebung/kaffeekasse.bak >> ~/belege/kasse-zeilen.txt")
    #expect(engine.state.completedTracks == 2)

    engine.run("cp /srv/rechenwerk/uebung/kaffeekasse.bak /srv/rechenwerk/uebung/kaffeekasse.csv")
    #expect(engine.state.evidences.allSatisfy { $0.validated })
}

// MARK: - Vorwurf

private func solveEvidence(_ engine: inout GameEngine) {
    engine.run("ls -l /srv/rechenwerk/uebung/ > ~/belege/kasse-meta.txt")
    engine.run("grep 2026-04-15 /srv/rechenwerk/uebung/kaffeekasse.csv > ~/belege/kasse-zeilen.txt")
    engine.run("grep 2026-04-15 /srv/rechenwerk/uebung/kaffeekasse.bak >> ~/belege/kasse-zeilen.txt")
}

@Test("Vorwurf ohne Verdächtigen wird abgelehnt")
func testAccusationWithoutSuspect() {
    let engine = makeEngine()
    let result = engine.evaluateAccusation(suspectID: nil, evidenceIDs: [])
    #expect(result.outcome != .accepted)
}

@Test("Vorwurf mit zu wenigen Belegen wird abgelehnt")
func testAccusationWithTooFewEvidence() {
    var engine = makeEngine()
    solveEvidence(&engine)
    let onlyMeta = engine.state.evidences.filter { $0.specID == "kasse-meta" }.map(\.id)
    let result = engine.evaluateAccusation(suspectID: "kaffee", evidenceIDs: Set(onlyMeta))
    #expect(result.outcome != .accepted)
    if case .missingEvidence = result.outcome {} else {
        Issue.record("Erwartet missingEvidence, erhalten: \(result.outcome)")
    }
}

@Test("Vorwurf ohne Auswahl der Belege wird abgelehnt")
func testAccusationWithoutSelection() {
    var engine = makeEngine()
    solveEvidence(&engine)
    // Belege sind da, aber nicht ausgewaehlt.
    let result = engine.evaluateAccusation(suspectID: "kaffee", evidenceIDs: [])
    #expect(result.outcome != .accepted)
}

@Test("Vorwurf ohne Belege aus beiden Spuren wird abgelehnt")
func testAccusationNeedsBothTracks() {
    var engine = makeEngine()
    solveEvidence(&engine)
    let onlyMeta = engine.state.evidences.filter { $0.specID == "kasse-meta" }.map(\.id)
    let result = engine.evaluateAccusation(suspectID: "kaffee", evidenceIDs: Set(onlyMeta))
    if case .missingEvidence = result.outcome {} else {
        Issue.record("Erwartet missingEvidence, erhalten: \(result.outcome)")
    }
}

@Test("Vorwurf vor der Reparatur wird abgelehnt")
func testAccusationBeforeRepair() {
    var engine = makeEngine()
    solveEvidence(&engine)
    let all = Set(engine.state.evidences.map(\.id))
    let result = engine.evaluateAccusation(suspectID: "kaffee", evidenceIDs: all)
    if case .notRepaired = result.outcome {} else {
        Issue.record("Erwartet notRepaired, erhalten: \(result.outcome)")
    }
}

@Test("Ein falscher Verdächtiger wird abgelehnt")
func testWrongSuspect() {
    var engine = makeEngine()
    solveEvidence(&engine)
    engine.run("cp /srv/rechenwerk/uebung/kaffeekasse.bak /srv/rechenwerk/uebung/kaffeekasse.csv")
    let all = Set(engine.state.evidences.map(\.id))
    let result = engine.evaluateAccusation(suspectID: "timo", evidenceIDs: all)
    if case .wrongSuspect = result.outcome {} else {
        Issue.record("Erwartet wrongSuspect, erhalten: \(result.outcome)")
    }
    #expect(result.message.contains("Probelauf bestanden") == false)
}

@Test("Die korrekte Loesung wird angenommen")
func testCorrectSolution() {
    var engine = makeEngine()
    solveEvidence(&engine)
    engine.run("cp /srv/rechenwerk/uebung/kaffeekasse.bak /srv/rechenwerk/uebung/kaffeekasse.csv")
    let all = Set(engine.state.evidences.map(\.id))
    let result = engine.evaluateAccusation(suspectID: "kaffee", evidenceIDs: all)
    #expect(result.outcome == .accepted)
    #expect(result.message == "Probelauf bestanden. Jetzt wird es ernst.")
}

// MARK: - Persistenz

@Test("JSON-Roundtrip inklusive Navigation")
func testJSONRoundtrip() throws {
    var engine = makeEngine()
    solveEvidence(&engine)
    engine.run("cd /srv/rechenwerk/uebung")
    engine.setPage(.aktenwand)
    engine.setSelectedSuspect("kaffee")
    engine.setSelectedEvidenceIDs(Set(engine.state.evidences.map(\.id)))

    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    let data = try encoder.encode(engine.state)
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let restored = try decoder.decode(GameState.self, from: data)

    #expect(restored.page == .aktenwand)
    #expect(restored.cwd == "/srv/rechenwerk/uebung")
    #expect(restored.selectedSuspectID == "kaffee")
    #expect(restored.selectedEvidenceIDs == engine.state.selectedEvidenceIDs)
    #expect(restored.evidences.count == engine.state.evidences.count)
    #expect(restored.fs.files.count == engine.state.fs.files.count)
    #expect(restored.transcript.count == engine.state.transcript.count)
}

@Test("Store schreibt und liest den Spielstand")
func testStoreRoundtrip() throws {
    let dir = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("staffelzwei-test-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: dir) }

    let store = GameStore(directory: dir)
    var engine = GameEngine()
    solveEvidence(&engine)
    engine.setPage(.vorwurf)

    try store.save(engine.state)
    #expect(FileManager.default.fileExists(atPath: store.fileURL.path))

    switch store.load() {
    case .loaded(let state):
        #expect(state.page == .vorwurf)
        #expect(state.evidences.count == 2)
        #expect(state.evidences.allSatisfy { $0.validated })
    case .fresh:
        Issue.record("Erwartet geladenen Spielstand")
    case .corrupt(let reason):
        Issue.record("Erwartet geladenen Spielstand, aber korrupt: \(reason)")
    }
}

@Test("Ein defekter Store bleibt unveraendert erhalten")
func testCorruptStoreIsPreserved() throws {
    let dir = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("staffelzwei-test-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: dir) }

    let store = GameStore(directory: dir)
    let broken = "{ this is not json"
    try Data(broken.utf8).write(to: store.fileURL)

    switch store.load() {
    case .corrupt:
        #expect(true)
    case .loaded:
        Issue.record("Erwartet corrupt")
    case .fresh:
        Issue.record("Erwartet corrupt, erhalten fresh")
    }

    // Die kaputte Datei darf nicht still überschrieben werden.
    let content = try String(contentsOf: store.fileURL, encoding: .utf8)
    #expect(content == broken)
}

@Test("Reset loescht nur eigene Daten und legt ein Backup an")
func testResetOnlyOwnData() throws {
    let dir = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("staffelzwei-test-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: dir) }

    let fremd = dir.appendingPathComponent("fremde-datei.txt")
    try Data("fremd".utf8).write(to: fremd)

    let store = GameStore(directory: dir)
    try store.save(GameState())
    let backup = try store.reset()

    #expect(FileManager.default.fileExists(atPath: backup.path))
    #expect(FileManager.default.fileExists(atPath: fremd.path))
    #expect(FileManager.default.fileExists(atPath: store.fileURL.path) == false)

    if case .fresh = store.load() {} else {
        Issue.record("Erwartet frischen Zustand nach Reset")
    }
}

@Test("Ein Neustart setzt den Zustand nicht zurueck")
func testRestartKeepsState() throws {
    let dir = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("staffelzwei-test-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: dir) }

    let store = GameStore(directory: dir)
    var engine = GameEngine()
    solveEvidence(&engine)
    try store.save(engine.state)

    // "Neustart": neuer Prozess, gleiche Datei.
    let reloaded: GameState
    switch store.load() {
    case .loaded(let state): reloaded = state
    case .fresh: Issue.record("Erwartet Spielstand"); reloaded = GameState()
    case .corrupt(let reason): Issue.record("Korrupt: \(reason)"); reloaded = GameState()
    }

    #expect(reloaded.evidences.count == 2)
    #expect(reloaded.completedTracks == 2)
    #expect(reloaded.fs.file(at: "/home/azubi/belege/kasse-meta.txt") != nil)
}

@Test("Ein Neustart behaelt auch die Auswahl im Vorwurf")
func testRestartKeepsSelection() throws {
    let dir = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("staffelzwei-test-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: dir) }

    let store = GameStore(directory: dir)
    var engine = GameEngine()
    solveEvidence(&engine)
    engine.setSelectedSuspect("kaffee")
    engine.setSelectedEvidenceIDs(Set(engine.state.evidences.map(\.id)))
    engine.setPage(.vorwurf)
    try store.save(engine.state)

    if case .loaded(let state) = store.load() {
        #expect(state.selectedSuspectID == "kaffee")
        #expect(state.selectedEvidenceIDs.count == 2)
        #expect(state.page == .vorwurf)
    } else {
        Issue.record("Erwartet geladenen Spielstand")
    }
}
