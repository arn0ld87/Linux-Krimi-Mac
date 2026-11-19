import Foundation
import Testing

@testable import StaffelCore

// MARK: - Hilfsfunktionen

private func makeTempDir(_ label: String) -> URL {
    FileManager.default.temporaryDirectory
        .appendingPathComponent("staffelzwei-\(label)-\(UUID().uuidString)", isDirectory: true)
}

private func normalizedPath(_ url: URL) -> String {
    url.standardizedFileURL.resolvingSymlinksInPath().path
}

// MARK: - Speicherisolation

@Test("Ein explizites Verzeichnis hat Vorrang vor APP_STORE")
func testExplicitDirectoryWinsOverAppStore() {
    let envDir = makeTempDir("env")
    let explicitDir = makeTempDir("explicit")
    defer {
        setenv("APP_STORE", "", 1)
        try? FileManager.default.removeItem(at: envDir)
        try? FileManager.default.removeItem(at: explicitDir)
    }
    setenv("APP_STORE", envDir.path, 1)

    // Der Testpfad gewinnt: Tests treffen niemals fremde Daten.
    #expect(normalizedPath(GameStore(directory: explicitDir).directory) == normalizedPath(explicitDir))
    // Ohne expliziten Pfad gilt APP_STORE.
    #expect(normalizedPath(GameStore().directory) == normalizedPath(envDir))
}

@Test("Ein defekter Spielstand wird nicht still überschrieben")
func testCorruptStoreIsNotOverwrittenOnSave() throws {
    let dir = makeTempDir("corrupt")
    defer { try? FileManager.default.removeItem(at: dir) }
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

    var store = GameStore(directory: dir)
    let broken = "{ this is not json"
    try Data(broken.utf8).write(to: store.fileURL)

    if case .corrupt = store.load() {} else {
        Issue.record("Erwartet corrupt")
    }
    store.protectFromOverwrite()
    #expect(store.isWriteProtected)

    // Ein Speichern muss scheitern ...
    #expect(throws: GameStore.StoreError.writeProtected) {
        try store.save(GameState())
    }
    // ... und die defekte Datei byte-identisch lassen.
    let content = try String(contentsOf: store.fileURL, encoding: .utf8)
    #expect(content == broken)
}

@Test("Ein bestätigtes Zurücksetzen hebt den Schreibschutz auf und sichert die alte Datei")
func testLiftWriteProtectionKeepsBackup() throws {
    let dir = makeTempDir("reset")
    defer { try? FileManager.default.removeItem(at: dir) }
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

    var store = GameStore(directory: dir)
    let broken = "{ kaputt"
    try Data(broken.utf8).write(to: store.fileURL)
    store.protectFromOverwrite()

    let backup = try store.liftWriteProtection()
    #expect(backup != nil)
    #expect(store.isWriteProtected == false)

    // Das Backup enthält den defekten Inhalt.
    let backupContent = try String(contentsOf: backup!, encoding: .utf8)
    #expect(backupContent == broken)

    // Danach darf wieder gespeichert werden.
    try store.save(GameState())
    #expect(FileManager.default.fileExists(atPath: store.fileURL.path))
}

@Test("Ein Store schreibt nur in sein eigenes Verzeichnis")
func testStoreStaysInsideItsDirectory() throws {
    let dir = makeTempDir("scope")
    defer { try? FileManager.default.removeItem(at: dir) }

    let store = GameStore(directory: dir)
    try store.save(GameState())

    let contents = try FileManager.default.contentsOfDirectory(atPath: dir.path)
    #expect(contents.contains("spielstand.json"))
    #expect(contents.allSatisfy { $0.hasPrefix("spielstand") })
}

// MARK: - Pfadnormalisierung

@Test("~ löst unabhängig vom Arbeitsverzeichnis gegen das Home auf")
func testTildeIsIndependentOfCwd() {
    #expect(VPath.normalize("~/belege/kasse-meta.txt", cwd: "/srv/rechenwerk/uebung") == "/home/azubi/belege/kasse-meta.txt")
    #expect(VPath.normalize("~/belege/kasse-meta.txt", cwd: "/home/azubi") == "/home/azubi/belege/kasse-meta.txt")
    #expect(VPath.normalize("~", cwd: "/srv") == "/home/azubi")
    #expect(VPath.normalize("~/", cwd: "/srv") == "/home/azubi")
    #expect(VPath.normalize("../..", cwd: "/srv/rechenwerk/uebung") == "/srv")
}

// MARK: - Transaktionale Fehler

@Test("Eine fehlgeschlagene Umleitung ändert weder cwd noch Dateiwelt")
func testFailedRedirectChangesNothing() {
    var engine = GameEngine()
    let fsBefore = engine.state.fs
    let cwdBefore = engine.state.cwd

    let result = engine.run("cd /srv/rechenwerk/uebung > /etc/verboten")

    #expect(result.isError)
    #expect(engine.state.cwd == cwdBefore)
    #expect(engine.state.fs.files == fsBefore.files)
    #expect(engine.state.fs.directories == fsBefore.directories)
}

@Test("Eine fehlgeschlagene Umleitung nach einem gültigen cd lässt den Befehl ins Leere laufen")
func testFailedRedirectAfterValidCommand() {
    var engine = GameEngine()
    let cwdBefore = engine.state.cwd

    // `ls` funktioniert, die Umleitung nicht: nichts darf passieren.
    let result = engine.run("ls /srv/rechenwerk/uebung/ > /srv/rechenwerk/uebung/kaffeekasse.bak")

    #expect(result.isError)
    #expect(engine.state.cwd == cwdBefore)
    #expect(engine.state.fs.file(at: EpisodeCatalog.bakPath)?.content == EpisodeCatalog.originalCSV)
}

// MARK: - Vollständiger Probelauf

@Test("Der vollständige Probelauf repariert die Liste und wird angenommen")
func testFullProbelauf() {
    var engine = GameEngine()

    #expect(engine.run("ls -l /srv/rechenwerk/uebung/ > ~/belege/kasse-meta.txt").isError == false)
    #expect(engine.run("grep 2026-04-15 /srv/rechenwerk/uebung/kaffeekasse.csv > ~/belege/kasse-zeilen.txt").isError == false)
    #expect(engine.run("grep 2026-04-15 /srv/rechenwerk/uebung/kaffeekasse.bak >> ~/belege/kasse-zeilen.txt").isError == false)
    #expect(engine.run("cp /srv/rechenwerk/uebung/kaffeekasse.bak /srv/rechenwerk/uebung/kaffeekasse.csv").isError == false)

    #expect(engine.state.repaired)
    #expect(engine.state.completedTracks == 2)

    let repaired = engine.state.fs.file(at: EpisodeCatalog.csvPath)
    #expect(repaired?.content == EpisodeCatalog.originalCSV)
    // Die Rechte des Ziels bleiben erhalten.
    #expect(repaired?.meta.owner == "kaffee")
    #expect(repaired?.meta.group == "azubi")
    #expect(repaired?.meta.permissions == 0o664)

    // Die Sicherung wird durch die Reparatur nicht angetastet.
    let backup = engine.state.fs.file(at: EpisodeCatalog.bakPath)
    #expect(backup?.content == EpisodeCatalog.originalCSV)
    #expect(backup?.meta.owner == "root")
    #expect(backup?.meta.permissions == 0o644)

    let all = Set(engine.state.evidences.map(\.id))
    let result = engine.evaluateAccusation(suspectID: "kaffee", evidenceIDs: all)
    #expect(result.outcome == .accepted)
    #expect(result.message == "Probelauf bestanden. Jetzt wird es ernst.")
}

@Test("Eine Datei mit passendem Namen, aber falschem Inhalt, ist kein Beleg")
func testEvidenceNeedsRealOutput() {
    var engine = GameEngine()

    // Die Datei heisst wie ein Beleg, enthält aber nicht die geforderte Ausgabe.
    #expect(engine.run("ls /home/azubi > ~/belege/kasse-meta.txt").isError == false)
    let evidence = engine.state.evidences.first { $0.specID == "kasse-meta" }
    #expect(evidence != nil)
    #expect(evidence?.validated == false)
    #expect(engine.state.completedTracks == 0)
}
