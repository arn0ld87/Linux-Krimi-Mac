import SwiftUI
import AppKit
import StaffelCore
// StaffelZwei
//   StaffelZwei                      die App
//   APP_STORE=<dir> StaffelZwei      Spielstand in einem eigenen Verzeichnis (Tests, Screens)
//   APP_SNAPSHOT=<dir> StaffelZwei   PNG je Seite in Light und Dark, dann beenden
//   APP_GRID=1 StaffelZwei           8-Pt-Raster und Layout-Proben über das Fenster
//   StaffelZwei --selftest           echte UI bedienen, PASS/FAIL je Schritt, Exitcode 0 oder 1
@main
enum StaffelZweiEntryPoint {
    @MainActor
    static func main() {
        if SelfTest.requested || Snapshot.requested {
            let mode = SelfTest.requested ? "SELFTEST" : "SNAPSHOT"
            guard let path = ProcessInfo.processInfo.environment["APP_STORE"],
                  path.hasPrefix("/"),
                  isTemporaryStore(path) else {
                print("\(mode) refused: set APP_STORE to an existing isolated temporary directory")
                exit(1)
            }
        }
        StaffelZweiApp.main()
    }

    private static func isTemporaryStore(_ path: String) -> Bool {
        let manager = FileManager.default
        var isDirectory: ObjCBool = false
        guard manager.fileExists(atPath: path, isDirectory: &isDirectory),
              isDirectory.boolValue else { return false }

        let store = URL(fileURLWithPath: path, isDirectory: true)
            .resolvingSymlinksInPath().standardizedFileURL.path
        var roots = [URL(fileURLWithPath: "/tmp", isDirectory: true)]
        let capacity = confstr(_CS_DARWIN_USER_TEMP_DIR, nil, 0)
        if capacity > 0 {
            var buffer = [CChar](repeating: 0, count: capacity)
            if confstr(_CS_DARWIN_USER_TEMP_DIR, &buffer, capacity) == capacity {
                let path = buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }
                roots.append(URL(fileURLWithPath: String(decoding: path, as: UTF8.self), isDirectory: true))
            }
        }
        guard roots.contains(where: {
            let root = $0.resolvingSymlinksInPath().standardizedFileURL.path
            return store.hasPrefix(root + "/")
        }) else { return false }

        let files = ["spielstand.json", "spielstand.json.tmp", "linux-arm64.raw", "linux-arm64.lock"]
        let campaignPaths = ["aktive-episode.txt", "episoden"] + (1...3).flatMap { episode in
            ["episoden/\(episode)"] + files.map { "episoden/\(episode)/" + $0 }
        }
        return (files + campaignPaths).allSatisfy {
            (try? manager.destinationOfSymbolicLink(atPath: store + "/" + $0)) == nil
        }
    }
}

struct StaffelZweiApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var model = AppModel()
    @Environment(\.openSettings) private var openSettings
    var body: some Scene {
        WindowGroup("StaffelZwei") {
            ContentView(model: model)
                .preferredColorScheme(model.appearance.colorScheme)
                .overlay { if GridOverlay.enabled { GridOverlay() } }
                .frame(minWidth: 1000, minHeight: 700)
                .onAppear {
                    NSApp.setActivationPolicy(.regular)
                    NSApp.activate(ignoringOtherApps: true)
                    Debug.log("onAppear: window sichtbar")
                    Snapshot.runIfRequested(model: model, openSettings: openSettings)
                    SelfTest.runIfRequested(model: model)
                }
        }
        .defaultSize(width: 1240, height: 820)
        .commands {
            CommandGroup(replacing: .newItem) { }
            CommandMenu("Fall") {
                Button("Einsatzrahmen") { model.page = .briefing }
                    .keyboardShortcut("1", modifiers: .command)
                Button("Terminal") { model.page = .terminal }
                    .keyboardShortcut("2", modifiers: .command)
                Button("Aktenwand") { model.page = .aktenwand }
                    .keyboardShortcut("3", modifiers: .command)
                Button(model.episode.id == 7 ? "Übergabe" : "Vorwurf") { model.page = .vorwurf }
                    .keyboardShortcut("4", modifiers: .command)
                Button("Hilfe & Werkzeuge") { model.page = .help }
                    .keyboardShortcut("5", modifiers: .command)
                if model.supportsDesktop {
                    Button("Linux-Bildschirm") { model.page = .desktop }
                        .keyboardShortcut("6", modifiers: .command)
                }
                Divider()
                Button(model.episode.id == 7 ? "Übergabe abgeben" : "Vorwurf prüfen") {
                    if model.episode.id == 7 {
                        Task { _ = await model.submitFinale() }
                    } else {
                        model.submitAccusation()
                    }
                }
                    .keyboardShortcut(.return, modifiers: .command)
                    .disabled(model.page != .vorwurf || model.terminalBusy)
            }
            CommandGroup(replacing: .help) {
                Button("Hilfe & Werkzeuge öffnen") { model.page = .help }
            }
        }
        Settings {
            SettingsView(model: model)
                .overlay { if GridOverlay.enabled { GridOverlay() } }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        // Ein direkt gestartetes Binary ist zunächst keine Vordergrund-App
        // (Richtlinie "prohibited"). Ohne "regular" legt SwiftUI kein Fenster an.
        // Der früheste sichere Zeitpunkt ist deshalb willFinishLaunching.
        let changed = NSApp.setActivationPolicy(.regular)
        Debug.log("applicationWillFinishLaunching: policy jetzt \(NSApp.activationPolicy().rawValue) (geaendert: \(changed))")
    }
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.activate(ignoringOtherApps: true)
        Debug.log("applicationDidFinishLaunching: windows=\(NSApp.windows.count) policy=\(NSApp.activationPolicy().rawValue)")
        // Die Watchdogs laufen ab hier, nicht erst ab onAppear: fehlt das
        // Fenster, käme onAppear nie und der Lauf hinge endlos.
        SelfTest.startWatchdog()
        Snapshot.startWatchdog()
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            Debug.log("nach 2s: windows=\(NSApp.windows.count) visible=\(NSApp.windows.filter(\.isVisible).count)")
            for window in NSApp.windows {
                Debug.log("  window \(window.windowNumber) visible=\(window.isVisible) main=\(window.canBecomeMain) sheet=\(window.isSheet) size=\(window.frame.size)")
            }
        }
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
    /// Das Ergebnis des Selbsttests wird nach dem normalen Beenden zum Exitcode.
    ///
    /// Ein abgebrochener Selbsttest bleibt Fehler: nur ein vollständig
    /// gelaufener Test (SelfTest.completed) liefert Exitcode 0.
    func applicationWillTerminate(_ notification: Notification) {
        if SelfTest.requested {
            exit(SelfTest.completed ? 0 : 1)
        }
        if Snapshot.requested {
            exit(Snapshot.exitCode)
        }
    }
}

// MARK: - Settings
struct SettingsView: View {
    @Bindable var model: AppModel
    @State private var showResetConfirmation = false
    var body: some View {
        TabView {
            GeneralSettings(model: model, showResetConfirmation: $showResetConfirmation)
                .tabItem { Label("Allgemein", systemImage: "gearshape") }
        }
        .frame(width: 460, height: 320)
    }
}
struct GeneralSettings: View {
    @Bindable var model: AppModel
    @Binding var showResetConfirmation: Bool
    var body: some View {
        Form {
            Section("Darstellung") {
                Picker("Erscheinungsbild", selection: $model.appearance) {
                    ForEach(AppModel.AppearancePreference.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .help("Hell, Dunkel oder die Systemeinstellung verwenden")
            }
            Section("Übungsterminal") {
                Label("Befehle laufen als azubi in einer lokalen Alpine-Linux-VM.", systemImage: "info.circle")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Label("Die virtuelle Maschine läuft offline und hat eine eigene Festplatte.", systemImage: "network.slash")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Section("Tastatur") {
                Label("Cmd-1 … Cmd-5 – Seiten wechseln", systemImage: "keyboard")
                Label("Cmd-Return – Vorwurf prüfen", systemImage: "keyboard")
                Label("Cmd-, – diese Einstellungen", systemImage: "keyboard")
            }
            Section("Spielstand") {
                Text("Der Spielstand dieser Episode liegt in \(model.store.directory.path)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                Button("Fortschritt zurücksetzen…") {
                    showResetConfirmation = true
                }
                .disabled(model.terminalBusy)
                .confirmationDialog(
                    "Fortschritt wirklich zurücksetzen?",
                    isPresented: $showResetConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("Zurücksetzen", role: .destructive) {
                        model.resetProgress()
                    }
                    Button("Abbrechen", role: .cancel) { }
                } message: {
                    Text("Der Spielstand und die Linux-Festplatte werden im selben Ordner gesichert. Die Übung beginnt von vorn.")
                }
            }
        }
        .formStyle(.grouped)
    }
}
