import AppKit
import IOKit.pwr_mgt
import SwiftUI
import StaffelCore

/// Screenshot-Modus für Agenten.
///
///   APP_STORE=/tmp/m1.store APP_SNAPSHOT=/tmp/m1-shots \
///     dist/NACHTDIFF.app/Contents/MacOS/StaffelZwei
///
/// Schreibt je Seite einen PNG in Light und Dark und legt daneben die
/// Layout-JSON mit den Grid-Proben ab (geprüft mit tools/check-layout.swift).
/// Der Modus verändert keinen Spielstand: Er zeigt den Zustand, der im
/// APP_STORE liegt, und wechselt nur die Seite.
enum Snapshot {
    private static var started = false
    /// Wird von AppDelegate.applicationWillTerminate als Exitcode benutzt.
    /// Startet ungleich 0 und wird nur nach einem vollständigen Lauf auf 0 gesetzt.
    static var exitCode: Int32 = 1
    /// true, sobald APP_SNAPSHOT gesetzt ist.
    static var requested: Bool {
        ProcessInfo.processInfo.environment["APP_SNAPSHOT"]?.isEmpty == false
    }
    private static var failures = 0
    private static var captures = 0
    private static var watchdogStarted = false

    /// Startet den Watchdog. Idempotent.
    ///
    /// Läuft ab dem App-Start, nicht erst ab `onAppear`: fehlt das Fenster,
    /// käme der Snapshot-Lauf nie in Gang und die App hinge endlos.
    static func startWatchdog() {
        guard requested, !watchdogStarted else { return }
        watchdogStarted = true
        let env = ProcessInfo.processInfo.environment
        let seconds = env["APP_SNAPSHOT_TIMEOUT"].flatMap(Double.init) ?? 150
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) {
            Task { @MainActor in
                guard Snapshot.exitCode != 0 else { return }
                print("SNAPSHOT TIMEOUT after \(Int(seconds))s")
                Snapshot.exitCode = 1
                fflush(stdout)
                NSApp.terminate(nil)
            }
        }
    }

    static func runIfRequested(model: AppModel, openSettings: OpenSettingsAction) {
        let env = ProcessInfo.processInfo.environment
        guard let dir = env["APP_SNAPSHOT"], !dir.isEmpty else { return }
        guard !started else { return }
        started = true
        startWatchdog()
        // Snapshots laufen nie gegen echte Nutzerdaten.
        guard let store = env["APP_STORE"], !store.isEmpty else {
            print("SNAPSHOT refused: set APP_STORE to a directory in /tmp")
            exitCode = 1
            NSApp.terminate(nil)
            return
        }
        Task { @MainActor in
            // Ein schlafendes Display liefert screencapture nichts. Nutzeraktivität
            // weckt es und hält es bis zum Ende des Laufs wach.
            var activity: IOPMAssertionID = 0
            IOPMAssertionDeclareUserActivity("Snapshots" as CFString, kIOPMUserActiveLocal, &activity)
            var awake: IOPMAssertionID = 0
            IOPMAssertionCreateWithName(kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
                                        IOPMAssertionLevel(kIOPMAssertionLevelOn),
                                        "Snapshots" as CFString, &awake)
            try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
            try? await Task.sleep(for: .seconds(1.5))
            for mode in ["light", "dark"] {
                model.appearance = mode == "light" ? .light : .dark
                for page in AppPage.allCases where page != .desktop {
                    model.page = page
                    try? await Task.sleep(for: .seconds(0.9))
                    let path = "\(dir)/\(page.rawValue)-\(mode).png"
                    if capture(to: path) { verifyLayout(for: path) }
                }
            }
            // Das Settings-Fenster separat: es ist ein eigenes Fenster.
            let main = NSApp.windows.first { $0.canBecomeMain && !$0.isSheet }
            openSettings()
            try? await Task.sleep(for: .seconds(1.2))
            for mode in ["light", "dark"] {
                model.appearance = mode == "light" ? .light : .dark
                try? await Task.sleep(for: .seconds(0.9))
                let settings = NSApp.windows.first { $0.isVisible && $0 !== main && !$0.isSheet }
                if settings == nil {
                    print("SNAPSHOT FAIL settings window missing (\(mode))")
                    failures += 1
                    continue
                }
                capture(to: "\(dir)/settings-\(mode).png", window: settings, layout: false)
            }
            // Ein Snapshot zeigt den Zustand aus APP_STORE. Er ist kein
            // Nachweis des Core-Loops, sondern dient Layoutzwecken.
            print("SNAPSHOT note: zeigt den Zustand aus APP_STORE, kein Nachweis des Core-Loops")
            if failures == 0 {
                exitCode = 0
                print("SNAPSHOT PASS \(captures) captures in \(dir)")
            } else {
                exitCode = 1
                print("SNAPSHOT FAIL \(failures) problems, \(captures) captures in \(dir)")
            }
            // Ein offenes Sheet verweigert das Beenden, der Lauf würde warten.
            for window in NSApp.windows { if let sheet = window.attachedSheet { window.endSheet(sheet) } }
            NSApp.terminate(nil)
        }
    }

    /// Prüft, dass zu einem Snapshot echte Layoutdaten gehören.
    ///
    /// Ohne Layoutdaten ist die Aufnahme kein Layoutnachweis.
    private static func verifyLayout(for pngPath: String) {
        let layoutPath = pngPath.replacingOccurrences(of: ".png", with: "-layout.json")
        guard let data = FileManager.default.contents(atPath: layoutPath),
              let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let probes = object["probes"] as? [[String: Any]],
              !probes.isEmpty else {
            print("SNAPSHOT FAIL \(layoutPath): keine Layoutdaten")
            failures += 1
            return
        }
        print("SNAPSHOT LAYOUT \(layoutPath): \(probes.count) probes")
    }

    /// Nimmt das echte Fenster auf, damit Glas, Sidebar und Materialien genau
    /// so aussehen wie auf dem Schirm. Das braucht die Screen-Recording-
    /// Berechtigung des startenden Programms.
    @discardableResult
    private static func capture(to path: String, window: NSWindow? = nil, layout: Bool = true) -> Bool {
        // Eine andere App kann diese verdecken; verdeckte Fenster lassen sich
        // nicht aufnehmen.
        if NSApp.isHidden { NSApp.unhideWithoutActivation() }
        guard let window = window ?? NSApp.windows.first(where: { $0.canBecomeMain && !$0.isSheet }) else {
            print("SNAPSHOT FAIL \(path): kein Fenster")
            failures += 1
            return false
        }
        // Aktiv, wie ein Fenster, in dem jemand arbeitet.
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        if layout {
            let size = window.contentView?.bounds.size ?? .zero
            GridProbes.shared.write(to: path.replacingOccurrences(of: ".png", with: "-layout.json"),
                                    window: size)
        }
        try? FileManager.default.removeItem(atPath: path)
        // Die erste Aufnahme trifft manchbar kein Fenster. Dreimal versuchen.
        for _ in 1...3 {
            let shot = Process()
            shot.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
            shot.arguments = ["-x", "-o", "-l", String(window.windowNumber), path]
            try? shot.run()
            shot.waitUntilExit()
            if let attributes = try? FileManager.default.attributesOfItem(atPath: path),
               let bytes = attributes[.size] as? Int, bytes > 0 {
                print("SNAPSHOT \(path)")
                captures += 1
                return true
            }
            Thread.sleep(forTimeInterval: 0.5)
        }
        print("SNAPSHOT FAIL \(path): keine PNG")
        failures += 1
        return false
    }
}
