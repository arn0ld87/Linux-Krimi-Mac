import AppKit
import IOKit.pwr_mgt
import SwiftUI
import StaffelCore

/// Selbsttest der App: bedient die echte Oberfläche.
///
/// Der Test setzt keine Erfolgsflags und legt keine Belege von Hand an.
/// Er tippt die Befehle Zeichen für Zeichen in das echte Terminal-Feld,
/// drückt die echten Schaltflächen über Accessibility und prüft danach den
/// Zustand, den die App selbst erzeugt hat.
///
///   APP_STORE=/tmp/m1-selftest.store APP_SELFTEST_SHOTS=/tmp/m1-selftest-shots \
///     dist/StaffelZwei.app/Contents/MacOS/StaffelZwei --selftest
@MainActor
enum SelfTest {
    static var campaignRequested: Bool { Swift.CommandLine.arguments.contains("--campaign-selftest") }
    static var requested: Bool { Swift.CommandLine.arguments.contains("--selftest") || campaignRequested }
    /// Wird von AppDelegate.applicationWillTerminate als Exitcode benutzt.
    ///
    /// Startet bewusst ungleich 0: nur ein vollständig durchgelaufener
    /// Selbsttest darf den Exitcode auf 0 setzen. Bricht der Lauf vorher ab
    /// (Fenster fehlt, Exception, Watchdog, Beenden von aussen), bleibt der
    /// Exitcode ungleich 0.
    static var exitCode: Int32 = 1
    /// Erst true, wenn alle Prüfungen gelaufen sind und keine fehlgeschlagen ist.
    static var completed = false
    /// Zeitlimit für den gesamten Selbsttest. Danach wird abgebrochen.
    static let timeout: TimeInterval = 120
    private static var watchdogStarted = false
    private static var failures = 0
    private static var count = 0
    private static var shotsDirectory: String?
    private static var resultPath: String?

    /// Startet den Watchdog. Idempotent.
    ///
    /// Der Watchdog läuft schon ab dem App-Start, nicht erst ab `onAppear`:
    /// fehlt das Fenster (etwa weil der Bildschirm gesperrt ist), kommt
    /// `onAppear` nie und der Lauf würde sonst endlos hängen.
    static func startWatchdog() {
        guard requested, !watchdogStarted else { return }
        watchdogStarted = true
        let env = ProcessInfo.processInfo.environment
        let seconds = env["APP_SELFTEST_TIMEOUT"].flatMap(Double.init) ?? (campaignRequested ? 360 : timeout)
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) {
            Task { @MainActor in
                guard !SelfTest.completed else { return }
                print("SELFTEST TIMEOUT after \(Int(seconds))s")
                SelfTest.finish(code: 1)
            }
        }
    }

    static func runIfRequested(model: AppModel) {
        guard requested else { return }
        // Zeilenweise ausgeben, damit ein Absturz die vorherigen Zeilen behält.
        setvbuf(stdout, nil, _IOLBF, 0)
        let env = ProcessInfo.processInfo.environment
        guard let store = env["APP_STORE"], !store.isEmpty else {
            print("SELFTEST refused: set APP_STORE to a directory in /tmp")
            finish(code: 1)
            return
        }
        shotsDirectory = env["APP_SELFTEST_SHOTS"]
        resultPath = env["APP_SELFTEST_RESULT"]
        startWatchdog()
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.2))
            if campaignRequested {
                await driveCampaign(model: model)
            } else {
                await drive(model: model)
            }
        }
    }

    // MARK: - Ablauf

    private static func drive(model: AppModel) async {
        // Ein schlafendes Display liefert screencapture nichts.
        var awake: IOPMAssertionID = 0
        IOPMAssertionCreateWithName(kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
                                    IOPMAssertionLevel(kIOPMAssertionLevelOn),
                                    "SelfTest" as CFString, &awake)
        NSApp.activate(ignoringOtherApps: true)
        guard let window = NSApp.windows.first(where: { $0.canBecomeMain && !$0.isSheet }) else {
            check("app window is open", false)
            finish(code: 1)
            return
        }
        window.makeKeyAndOrderFront(nil)
        try? await Task.sleep(for: .milliseconds(700))
        check("app window is open", true)

        // 1. Befehle wirklich in das Terminal-Feld tippen.
        model.page = .terminal
        try? await Task.sleep(for: .milliseconds(700))
        await waitForTerminal(model)
        check("Alpine VM booted", model.linuxConnected, model.linuxMessage)
        guard model.linuxConnected else {
            finish(code: 1)
            return
        }
        guard let field = terminalField(in: window) else {
            check("terminal input field exists", false)
            finish(code: 1)
            return
        }
        check("terminal input field exists", true)
        window.makeFirstResponder(field)
        try? await Task.sleep(for: .milliseconds(250))

        let commands = [
            "uname -sm",
            "ls -l /srv/rechenwerk/uebung/ > ~/belege/kasse-meta.txt",
            "grep 2026-04-15 /srv/rechenwerk/uebung/kaffeekasse.csv > ~/belege/kasse-zeilen.txt",
            "grep 2026-04-15 /srv/rechenwerk/uebung/kaffeekasse.bak >> ~/belege/kasse-zeilen.txt",
            "cp /srv/rechenwerk/uebung/kaffeekasse.bak /srv/rechenwerk/uebung/kaffeekasse.csv",
        ]
        for command in commands {
            let before = model.state.transcript.count
            type(command, into: window)
            let typed = model.terminalInput == command
            check("typed text reaches the field: \(command)", typed,
                  typed ? "" : "field held \"\(model.terminalInput)\"")
            pressReturn(into: window)
            await waitForTerminal(model)
            let transcript = model.state.transcript
            check("command ran: \(command)",
                  transcript.count > before && transcript.contains { $0.text.contains(command) })
        }
        try? await Task.sleep(for: .milliseconds(300))

        check("commands run on ARM64 Linux",
              model.state.transcript.contains { $0.kind == .output && $0.text.contains("Linux aarch64") })
        check("evidence 'Metadaten der Kaffeekasse' is validated",
              model.state.evidences.first { $0.specID == "kasse-meta" }?.validated == true)
        check("evidence 'Zeilen um den 15. April' is validated",
              model.state.evidences.first { $0.specID == "kasse-zeilen" }?.validated == true)
        check("coffee fund is repaired", model.state.repaired == true)
        capture("01-terminal-nach-befehlen", in: window)

        // 2. Vorwurf: echte Schaltflächen drücken.
        model.page = .vorwurf
        try? await Task.sleep(for: .milliseconds(800))

        // 2a. Ohne Verdächtigen.
        pressButton("Prüfen", in: window)
        try? await Task.sleep(for: .milliseconds(300))
        check("no suspect gives a concrete hint",
              model.state.lastAccusationFeedback?.contains("Wähle zuerst einen Verdächtigen") == true,
              model.state.lastAccusationFeedback ?? "no feedback")

        // 2b. Verdächtiger gewählt, aber keine Belege ausgewählt.
        pressChoice("Kaffeeautomat", probe: "suspect-kaffee", in: window)
        try? await Task.sleep(for: .milliseconds(300))
        check("suspect row selects the suspect", model.selectedSuspectID == "kaffee",
              model.selectedSuspectID ?? "none")
        pressButton("Prüfen", in: window)
        try? await Task.sleep(for: .milliseconds(300))
        check("missing evidence gives a concrete hint",
              model.state.lastAccusationFeedback?.contains("Es fehlen anerkannte Belege") == true,
              model.state.lastAccusationFeedback ?? "no feedback")
        capture("02-vorwurf-ohne-belege", in: window)

        // 2c. Beide Belege auswählen, falscher Verdächtiger.
        pressChoice("Metadaten der Kaffeekasse", probe: "evidence-kasse-meta", in: window)
        try? await Task.sleep(for: .milliseconds(250))
        pressChoice("Zeilen um den 15. April", probe: "evidence-kasse-zeilen", in: window)
        try? await Task.sleep(for: .milliseconds(250))
        check("both evidences are selected", model.selectedEvidenceIDs.count == 2,
              "\(model.selectedEvidenceIDs.count) selected")
        pressChoice("Timo Kessler", probe: "suspect-timo", in: window)
        try? await Task.sleep(for: .milliseconds(250))
        pressButton("Prüfen", in: window)
        try? await Task.sleep(for: .milliseconds(400))
        check("wrong suspect is rejected with an explanation",
              model.state.lastAccusationFeedback?.contains("war es nicht") == true,
              model.state.lastAccusationFeedback ?? "no feedback")
        check("wrong suspect does not solve the case", model.state.solved == false)
        capture("03-vorwurf-falscher-verdachtiger", in: window)

        // 2d. Richtiger Verdächtiger -> Erfolg.
        pressChoice("Kaffeeautomat", probe: "suspect-kaffee", in: window)
        try? await Task.sleep(for: .milliseconds(250))
        check("correct suspect is selected", model.selectedSuspectID == "kaffee",
              model.selectedSuspectID ?? "none")
        pressButton("Prüfen", in: window)
        try? await Task.sleep(for: .milliseconds(600))
        check("accusation is accepted", model.state.solved == true)
        check("success message is shown",
              model.state.lastAccusationFeedback?.contains("Probelauf bestanden") == true,
              model.state.lastAccusationFeedback ?? "no feedback")
        // Nach dem Erfolg springt die App auf den Einsatzrahmen mit dem Erfolgsbanner.
        try? await Task.sleep(for: .milliseconds(500))
        check("app shows the briefing page after success", model.page == .briefing,
              model.page.rawValue)
        capture("04-erfolg", in: window)

        // Die Abschlusszeile steht vor dem Beenden. Nur ein Lauf ohne
        // Fehlschlag darf den Exitcode auf 0 setzen.
        print(failures == 0
              ? "SELFTEST PASS \(count) checks"
              : "SELFTEST FAIL \(failures) of \(count) checks")
        finish(code: failures == 0 ? 0 : 1)
    }

    // MARK: - Echte Eingaben

    private static func driveCampaign(model: AppModel) async {
        let cases: [(Int, [String], [String: String], [String])] = [
            (1, [
                "grep -B1 nadia /etc/sudoers.d/rw-fernwartung > ~/belege/rechte-zeile.txt",
                "ls -l /etc/sudoers.d/rw-fernwartung $(find /usr/local -perm -4000 -type f) > ~/belege/rechte-metadaten.txt",
                "grep sudoers.d /var/log/rechenwerk-audit.log > ~/belege/log-zeile.txt",
            ], ["kennung": "RW-1042"], [
                "sudo mv /etc/sudoers.d/rw-fernwartung ~/quarantaene/",
                "sudo mv /usr/local/bin/rw-status ~/quarantaene/",
            ]),
            (2, [
                "ps | grep -E 'rw-abgleich|crond' > ~/belege/prozess-zeile.txt",
                "grep 'change=RW-2122 ' /var/log/rechenwerk-wartung.log > ~/belege/wartung-zeile.txt",
            ], ["kennung": "RW-2122"], [
                "sudo crontab -u abgleich -r && sudo pkill -x rw-abgleich",
            ]),
            (3, [
                "grep -vxFf /var/log/rechenwerk-auth.log /srv/rechenwerk/log-spiegel/rechenwerk-auth.log > ~/belege/luecke-zeilen.txt",
                "cut -d' ' -f2 ~/belege/luecke-zeilen.txt | sort | uniq -c > ~/belege/konten-zaehlung.txt",
            ], ["zeitraum": "02:14-03:09"], [
                "mkdir -p ~/quarantaene && mv /srv/rechenwerk/wartung/bin/logkuerzen.sh ~/quarantaene/",
            ]),
            (4, [
                "test -s ~/faelle/04/freigabe.png",
                "head -n 1 ~/faelle/04/entwurf.tsv > ~/belege/anhang-kopf.txt",
                "grep '^RW-3074' ~/faelle/04/aenderungen.tsv > ~/belege/anhang-audit.txt",
            ], ["freigabe-id": "RW-3074", "zusatzfelder": "kontakt, kunden_ref", "vorlage-konto": "timo"], []),
            (5, [
                "cp ~/faelle/05/ausgang/info.txt ~/belege/export-status.txt",
                "sha256sum ~/faelle/05/ausgang/export-07.tsv | cut -d' ' -f1 > ~/belege/export-sha256.txt",
            ], ["export-paket": "EXPORT-07", "uebergabe-status": "offen"], [
                "mv ~/faelle/05/ausgang/export-07.tsv ~/faelle/05/quarantaene/",
            ]),
            (6, [
                "tail -n +2 ~/faelle/06/ausgang.tsv > ~/belege/zeit-originale.txt; tail -n +2 ~/faelle/06/journal.tsv >> ~/belege/zeit-originale.txt",
                "printf '%s\\t%s\\t%s\\n' 2026-04-18T00:20:00Z EXPORT-07 timo 2026-04-18T02:21:37Z RW-1051 nadia 2026-04-20T08:47:52Z RW-2122 nadia > ~/belege/zeitfolge.txt",
            ], ["ausgang-konto": "timo"], []),
            (7, [
                "cp ~/faelle/07/vorlagen/fallakte.txt ~/belege/finale-fallakte.txt",
            ], ["schluss-export": "timo", "schluss-loeschlauf": "nadia",
                "schluss-empfang": "unbelegt", "schluss-testlauf": "freigegebene_messwerte"], [
                "cp ~/faelle/07/freigabe/messwerte.tsv ~/faelle/07/betrieb/testausgang/",
                "head -n 1 ~/faelle/07/betrieb/testausgang/messwerte.tsv > ~/belege/finale-pruefung.txt",
            ]),
        ]

        check("episode 4 locked before episode 3 is solved", !model.isUnlocked(EpisodeCatalog.episode(id: 4)))
        for (id, collection, answers, repairs) in cases {
            model.selectEpisode(EpisodeCatalog.episode(id: id))
            await waitForTerminal(model)
            check("select episode \(id)", model.episode.id == id)
            model.startLinux()
            await waitForTerminal(model)
            check("episode \(id) VM booted", model.linuxConnected, model.linuxMessage)
            guard model.linuxConnected else { finish(code: 1); return }
            if id >= 4 {
                let result = model.engine.evaluateAccusation(suspectID: "timo", evidenceIDs: [])
                check("episode \(id) requires evidence", result.outcome != .accepted)
            }
            if id == 4 {
                await runCampaignCommand("printf 'falsche Kopfzeile\\n' > ~/belege/anhang-kopf.txt", model: model)
                check("episode 4 rejects wrong header", !model.state.isStepComplete("anhang-kopf"))
            }
            for command in collection {
                await runCampaignCommand(command, model: model)
            }
            for (step, solution) in answers.sorted(by: { $0.key < $1.key }) {
                let wrong = await model.submitAnswer(step == "schluss-empfang" ? "belegt" : "0000", for: step)
                check("episode \(id) rejects wrong answer: \(step)", wrong != nil)
                let accepted = await model.submitAnswer(solution, for: step)
                check("episode \(id) accepts correct answer: \(step)", accepted == nil, accepted ?? "")
            }
            if id == 7 {
                await runCampaignCommand(
                    "printf 'sensor_id\\ttemperatur_c\\tzeit_utc\\tkontakt\\n' > ~/faelle/07/betrieb/testausgang/messwerte.tsv",
                    model: model)
                check("episode 7 rejects additional fields", !model.state.isStepComplete("finale-testlauf"))
            }
            for command in repairs {
                await runCampaignCommand(command, model: model)
            }
            let expected = Set(model.episode.evidenceSpecs.map(\.id))
            let validated = Set(model.state.evidences.filter(\.validated).map(\.id))
            check("episode \(id) all evidence validated", expected == validated,
                  model.state.evidences.map { "\($0.id): \($0.content.trimmingCharacters(in: .whitespacesAndNewlines))" }
                      .joined(separator: " | "))
            let incomplete = model.episode.steps.filter { !model.state.isStepComplete($0.id) }
            check("episode \(id) all steps complete", incomplete.isEmpty, incomplete.map(\.id).joined(separator: ", "))
            model.selectedEvidenceIDs = validated
            if id == 7 {
                let message = await model.submitFinale()
                check("episode 7 accepts handoff", model.state.solved, message)
            } else {
                model.selectedSuspectID = model.episode.culpritID
                let result = model.submitAccusation()
                check("episode \(id) accepted accusation", result.outcome == .accepted, result.message)
            }
        }

        for id in 1...7 {
            model.selectEpisode(EpisodeCatalog.episode(id: id))
            await waitForTerminal(model)
            model.startLinux()
            await waitForTerminal(model)
            check("episode \(id) reopens with persistent Linux evidence",
                  model.linuxConnected && model.state.solved && model.state.repaired
                  && model.state.evidences.allSatisfy(\.validated), model.linuxMessage)
        }
        print(failures == 0 ? "CAMPAIGN PASS \(count) checks" : "CAMPAIGN FAIL \(failures) of \(count) checks")
        finish(code: failures == 0 ? 0 : 1)
    }

    private static func runCampaignCommand(_ command: String, model: AppModel) async {
        model.runCommand(command)
        await waitForTerminal(model)
        let last = model.state.transcript.last
        check("episode \(model.episode.id) command: \(command)", last?.kind != .error, last?.text ?? "")
    }

    private static func waitForTerminal(_ model: AppModel) async {
        let limit = ContinuousClock.now + .seconds(38)
        while model.terminalBusy, ContinuousClock.now < limit {
            try? await Task.sleep(for: .milliseconds(50))
        }
    }

    /// Tippt Zeichen für Zeichen in das gerade fokussierte Feld.
    private static func type(_ text: String, into window: NSWindow) {
        for character in text {
            guard let event = NSEvent.keyEvent(
                with: .keyDown, location: .zero, modifierFlags: [],
                timestamp: ProcessInfo.processInfo.systemUptime,
                windowNumber: window.windowNumber, context: nil,
                characters: String(character), charactersIgnoringModifiers: String(character),
                isARepeat: false, keyCode: 0) else { continue }
            NSApp.sendEvent(event)
        }
    }

    private static func pressReturn(into window: NSWindow) {
        guard let event = NSEvent.keyEvent(
            with: .keyDown, location: .zero, modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: window.windowNumber, context: nil,
            characters: "\r", charactersIgnoringModifiers: "\r",
            isARepeat: false, keyCode: 36) else { return }
        NSApp.sendEvent(event)
    }

    /// Drückt eine Schaltfläche über Accessibility, mit echtem Mausklick als Rückfallebene.
    @discardableResult
    private static func pressButton(_ label: String, in window: NSWindow) -> Bool {
        pressChoice(label, probe: "accusation", in: window)
    }

    @discardableResult
    private static func pressChoice(_ title: String, probe: String, in window: NSWindow) -> Bool {
        let pressed = button(labelContaining: title, in: window).map { performPress($0, in: window) }
            ?? clickProbe(probe, in: window)
        check("button '\(title)' pressed", pressed)
        return pressed
    }

    private static func clickProbe(_ name: String, in window: NSWindow) -> Bool {
        guard let frame = GridProbes.shared.probes["probe:\(name)"],
              let root = window.contentView else { return false }
        let top = frame.y + frame.height / 2
        let point = NSPoint(x: frame.x + frame.width / 2, y: root.isFlipped ? top : root.bounds.height - top)
        guard root.bounds.contains(point) else { return false }
        click(at: root.convert(point, to: nil), in: window)
        return true
    }

    private static func performPress(_ element: Any, in window: NSWindow) -> Bool {
        if let ax = element as? NSAccessibilityProtocol, ax.accessibilityPerformPress() { return true }
        // Rückfallebene: echter Mausklick an der Stelle des Elements.
        guard let ax = element as? NSAccessibilityProtocol else { return false }
        let frame = ax.accessibilityFrame()
        let screenPoint = NSPoint(x: frame.midX, y: frame.midY)
        let windowPoint = window.convertPoint(fromScreen: screenPoint)
        click(at: windowPoint, in: window)
        return true
    }

    private static func click(at point: NSPoint, in window: NSWindow) {
        let down = NSEvent.mouseEvent(
            with: .leftMouseDown, location: point, modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: window.windowNumber, context: nil,
            eventNumber: 0, clickCount: 1, pressure: 1)
        let up = NSEvent.mouseEvent(
            with: .leftMouseUp, location: point, modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: window.windowNumber, context: nil,
            eventNumber: 0, clickCount: 1, pressure: 0)
        if let down { window.sendEvent(down) }
        if let up { window.sendEvent(up) }
    }

    // MARK: - Accessibility

    private static func button(labelContaining text: String, in window: NSWindow) -> Any? {
        let elements = accessibilityElements(in: window.contentView)
        return elements.first { element in
            isButton(element) && (accessibleText(element)?.contains(text) ?? false)
        }
    }

    private static func isButton(_ element: Any) -> Bool {
        (element as? NSAccessibilityProtocol)?.accessibilityRole() == .button
    }

    private static func accessibleText(_ element: Any) -> String? {
        guard let ax = element as? NSAccessibilityProtocol else { return nil }
        return ax.accessibilityLabel() ?? ax.accessibilityTitle()
    }

    private static func accessibilityElements(in root: Any?) -> [Any] {
        var found: [Any] = []
        func walk(_ object: Any, depth: Int) {
            guard depth < 24, let ax = object as? NSAccessibilityProtocol else { return }
            guard let children = ax.accessibilityChildren() else { return }
            for child in children {
                found.append(child)
                walk(child, depth: depth + 1)
            }
        }
        if let root { walk(root, depth: 0) }
        return found
    }

    private static func terminalField(in window: NSWindow) -> NSTextField? {
        var result: NSTextField?
        func walk(_ view: NSView) {
            guard result == nil else { return }
            if let field = view as? NSTextField,
               field.placeholderString == "Befehl eingeben"
                || field.accessibilityLabel() == "Terminal-Eingabe" {
                result = field
                return
            }
            for subview in view.subviews { walk(subview) }
        }
        if let content = window.contentView { walk(content) }
        return result
    }

    // MARK: - Belegmaterial

    private static func capture(_ name: String, in window: NSWindow) {
        guard let directory = shotsDirectory else { return }
        try? FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
        let path = "\(directory)/\(name).png"
        try? FileManager.default.removeItem(atPath: path)
        let shot = Process()
        shot.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        shot.arguments = ["-x", "-o", "-l", String(window.windowNumber), path]
        try? shot.run()
        shot.waitUntilExit()
        print(FileManager.default.fileExists(atPath: path) ? "SHOT \(path)" : "SHOT FAILED \(path)")
    }

    private static func check(_ name: String, _ ok: Bool, _ detail: String = "") {
        count += 1
        if !ok { failures += 1 }
        print(ok ? "PASS \(name)" : "FAIL \(name)\(detail.isEmpty ? "" : ": \(detail)")")
    }

    /// Beendet über NSApp.terminate, nie über exit(), und schließt offene
    /// Sheets: ein Sheet verweigert das Beenden und der Lauf würde warten.
    static func finish(code: Int32) {
        exitCode = code
        // Nur ein vollständig gelaufener Test gilt als abgeschlossen.
        if code == 0 { completed = true }
        writeResult()
        fflush(stdout)
        for window in NSApp.windows { if let sheet = window.attachedSheet { window.endSheet(sheet) } }
        NSApp.terminate(nil)
    }

    /// Schreibt optional eine Ergebnisdatei mit Status und Anzahl.
    ///
    /// Der Status ist `completed` nur, wenn wirklich alle Prüfungen liefen und
    /// keine fehlschlug. Sonst `failed`.
    private static func writeResult() {
        guard let path = resultPath else { return }
        let file: [String: Any] = [
            "status": completed ? "completed" : "failed",
            "checks": count,
            "failures": failures,
            "exitCode": Int(exitCode),
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: file,
                                                    options: [.prettyPrinted, .sortedKeys]) else { return }
        try? data.write(to: URL(fileURLWithPath: path))
    }
}
