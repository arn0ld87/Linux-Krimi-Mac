import Foundation

/// Diagnoseausgabe nach stderr, hinter einem Schalter.
///
/// Eine GUI-App, deren Ausgabe in eine Datei geht, puffert `print`; die
/// Zeilen gehen beim Beenden verloren. Deshalb schreibt diese Hilfe direkt
/// nach stderr und nur, wenn APP_DEBUG=1 gesetzt ist.
enum Debug {
    static let enabled = ProcessInfo.processInfo.environment["APP_DEBUG"] == "1"

    static func log(_ message: String) {
        guard enabled else { return }
        FileHandle.standardError.write(Data((message + "\n").utf8))
    }
}
