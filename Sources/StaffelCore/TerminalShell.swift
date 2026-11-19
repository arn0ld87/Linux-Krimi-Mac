import Foundation

// MARK: - Shell-Eingabe

/// Ein vom Nutzer eingegebener Befehl.
public struct CommandLine: Sendable, Equatable {
    public let raw: String
    public let tokens: [String]
    /// Zielpfad bei `>` oder `>>`; nil ohne Umleitung.
    public let redirectPath: String?
    /// true bei `>>` (anhängen) statt `>` (ersetzen).
    public let redirectAppend: Bool

    public init(raw: String, tokens: [String], redirectPath: String?, redirectAppend: Bool) {
        self.raw = raw
        self.tokens = tokens
        self.redirectPath = redirectPath
        self.redirectAppend = redirectAppend
    }

    /// Zerlegt eine Eingabezeile in Tokens, Redirection und Argumente.
    ///
    /// Unterstützt einfache und doppelte Quotes, `>` und `>>`. Shell-Operatoren
    /// wie `|`, `&&`, `;`, `$(`, `` ` `` werden **nicht** interpretiert.
    public static func parse(_ input: String) throws -> CommandLine {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw ShellError.empty
        }

        // Verbotene Shell-Konstrukte werden explizit abgelehnt.
        for forbidden in ["|", "&", ";", "$(", "`", "<"] {
            if trimmed.contains(forbidden) {
                throw ShellError.unsupportedSyntax(forbidden)
            }
        }
        if trimmed.contains(">") {
            // > und >> sind erlaubt, aber nicht in Kombination mit Pipes.
        }

        var tokens: [String] = []
        var current = ""
        var quote: Character?
        var redirectPath: String?
        var redirectAppend = false
        var sawRedirect = false

        let chars = Array(trimmed)
        var i = 0
        while i < chars.count {
            let ch = chars[i]
            if let q = quote {
                if ch == q {
                    quote = nil
                } else {
                    current.append(ch)
                }
                i += 1
                continue
            }
            switch ch {
            case "'", "\"":
                quote = ch
            case ">":
                // Umleitungsziel beginnt; laufendes Token abschliessen.
                if !current.isEmpty { tokens.append(current); current = "" }
                if sawRedirect {
                    throw ShellError.unsupportedSyntax(">")
                }
                sawRedirect = true
                if i + 1 < chars.count && chars[i + 1] == ">" {
                    redirectAppend = true
                    i += 1
                }
                // Zielpfad einsammeln (bis Whitespace).
                i += 1
                // Whitespace zwischen Umleitungszeichen und Ziel ueberspringen:
                // `befehl > datei` ist genauso gueltig wie `befehl>datei`.
                while i < chars.count && chars[i].isWhitespace {
                    i += 1
                }
                var path = ""
                while i < chars.count && !chars[i].isWhitespace {
                    path.append(chars[i])
                    i += 1
                }
                path = path.trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
                if path.isEmpty { throw ShellError.missingRedirectTarget }
                redirectPath = path
                continue
            case " ", "\t":
                if !current.isEmpty { tokens.append(current); current = "" }
            default:
                current.append(ch)
            }
            i += 1
        }
        if quote != nil {
            throw ShellError.unclosedQuote
        }
        if !current.isEmpty { tokens.append(current) }
        guard !tokens.isEmpty else { throw ShellError.empty }

        return CommandLine(raw: trimmed, tokens: tokens, redirectPath: redirectPath, redirectAppend: redirectAppend)
    }
}

// MARK: - Fehler

public enum ShellError: Error, Equatable, Sendable {
    case empty
    case unclosedQuote
    case unsupportedSyntax(String)
    case missingRedirectTarget
    case unknownCommand(String)
    case missingArgument(String)
    case noSuchFile(String)
    case noSuchDirectory(String)
    case notADirectory(String)
    case isADirectory(String)
    case permissionDenied(String)
    case writeOutsideSandbox(String)
    case backupIsReadOnly(String)
    case patternNotFound(String, file: String)
    case invalidPattern(String)
    case sourceIsDirectory(String)
    case sameFile(String)
    case unsupportedInM1(String)

    public var message: String {
        switch self {
        case .empty:
            return "leer"
        case .unclosedQuote:
            return "unclosed quote"
        case .unsupportedSyntax(let s):
            return "Pipes, Verkettungen und Command-Substitution werden in dieser Übung nicht unterstützt: \(s)"
        case .missingRedirectTarget:
            return "Umleitung ohne Ziel"
        case .unknownCommand(let c):
            return "unknown command: \(c)"
        case .missingArgument(let c):
            return "\(c): missing argument"
        case .noSuchFile(let p):
            return "\(p): No such file or directory"
        case .noSuchDirectory(let p):
            return "\(p): No such file or directory"
        case .notADirectory(let p):
            return "\(p): Not a directory"
        case .isADirectory(let p):
            return "\(p): Is a directory"
        case .permissionDenied(let p):
            return "\(p): Permission denied"
        case .writeOutsideSandbox(let p):
            return "\(p): Schreiben ist nur unter ~/belege erlaubt"
        case .backupIsReadOnly(let p):
            return "\(p): Sicherung ist schreibgeschützt"
        case .patternNotFound(let p, let f):
            return "\(f): Keine Übereinstimmung für \(p)"
        case .invalidPattern(let p):
            return "\(p): ungültiges Suchmuster"
        case .sourceIsDirectory(let p):
            return "\(p): Is a directory"
        case .sameFile(let p):
            return "\(p): same file"
        case .unsupportedInM1(let s):
            return "\(s) wird in M1 nicht unterstützt"
        }
    }
}

// MARK: - Shell-Ausführung

/// Führt unterstützte Befehle gegen die virtuelle Dateiwelt aus.
///
/// Grundregel: Ein fehlgeschlagener Befehl verändert den Zustand nicht.
public struct Shell {
    public static let supportedCommands = [
        "pwd", "cd", "ls", "stat", "cat", "grep", "cp", "mkdir", "help", "clear",
    ]

    public var fs: VirtualFS
    public var cwd: String

    public init(fs: VirtualFS, cwd: String = VPath.home) {
        self.fs = fs
        self.cwd = cwd
    }

    /// Führt eine Zeile aus und liefert Ausgabe, neues cwd und mögliche Fehlermeldung.
    ///
    /// Ein fehlgeschlagener Befehl ist transaktional: Dateiwelt und
    /// Arbeitsverzeichnis bleiben exakt so, wie sie vor dem Aufruf waren.
    @discardableResult
    public mutating func run(_ input: String) -> ShellResult {
        let fsBefore = fs
        let cwdBefore = cwd
        do {
            let cmd = try CommandLine.parse(input)
            return try execute(cmd)
        } catch let error as ShellError {
            fs = fsBefore
            cwd = cwdBefore
            return ShellResult(output: error.message, isError: true)
        } catch {
            fs = fsBefore
            cwd = cwdBefore
            return ShellResult(output: String(describing: error), isError: true)
        }
    }

    private mutating func execute(_ cmd: CommandLine) throws -> ShellResult {
        let name = cmd.tokens[0]
        let args = Array(cmd.tokens.dropFirst())
        guard Self.supportedCommands.contains(name) else {
            throw ShellError.unknownCommand(name)
        }

        var output: String
        var newCwd = cwd

        switch name {
        case "pwd":
            output = cwd + "\n"

        case "help":
            output = helpText()

        case "clear":
            output = ""

        case "cd":
            guard let target = args.first else { throw ShellError.missingArgument("cd") }
            let resolved = try resolve(target)
            if resolved == VPath.root {
                newCwd = resolved
            } else if fs.isDirectory(resolved) {
                newCwd = resolved
            } else if fs.exists(at: resolved) {
                throw ShellError.notADirectory(resolved)
            } else {
                throw ShellError.noSuchDirectory(resolved)
            }
            output = ""

        case "ls":
            output = try runLs(args)

        case "stat":
            output = try runStat(args)

        case "cat":
            output = try runCat(args)

        case "grep":
            output = try runGrep(args)

        case "cp":
            output = try runCp(args)

        case "mkdir":
            output = try runMkdir(args)

        default:
            throw ShellError.unknownCommand(name)
        }

        cwd = newCwd

        // Umleitung: Ziel schreiben, danach den Erfolg melden.
        if let redirect = cmd.redirectPath {
            let target = VPath.normalize(redirect, cwd: cwd)
            guard let target else { throw ShellError.writeOutsideSandbox(redirect) }
            try assertWritable(target)
            var payload = output
            if cmd.redirectAppend, let existing = fs.file(at: target) {
                payload = existing.content + output
            }
            let meta = fs.file(at: target)?.meta ?? defaultMeta()
            fs.setFile(VFile(content: payload, meta: meta), at: target)
            // Terminal zeigt nach Umleitung die Shell-Nachricht, nicht die Nutzlast.
            return ShellResult(output: "", isError: false, redirectTarget: target)
        }

        return ShellResult(output: output, isError: false)
    }

    // MARK: Befehle

    private func runLs(_ args: [String]) throws -> String {
        let longFormat = args.contains("-l")
        let targets = args.filter { !$0.hasPrefix("-") }
        let paths = try targets.isEmpty ? [cwd] : targets.map { try resolve($0) }

        var out = ""
        for (index, path) in paths.enumerated() {
            if paths.count > 1 {
                if index > 0 { out += "\n" }
                out += "\(path):\n"
            }
            if fs.isDirectory(path) {
                if longFormat {
                    out += "total \(fs.children(of: path).count)\n"
                    for child in fs.children(of: path) {
                        out += longEntry(name: child.name, path: child.path, isDir: child.isDir) + "\n"
                    }
                } else {
                    let names = fs.children(of: path).map(\.name).joined(separator: " ")
                    out += names + (names.isEmpty ? "" : "\n")
                }
            } else if let file = fs.file(at: path) {
                if longFormat {
                    out += longEntry(name: VPath.lastComponent(path), path: path, isDir: false) + "\n"
                } else {
                    out += VPath.lastComponent(path) + "\n"
                }
                _ = file
            } else {
                throw ShellError.noSuchFile(path)
            }
        }
        return out
    }

    private func longEntry(name: String, path: String, isDir: Bool) -> String {
        let file = fs.file(at: path)
        let meta = file?.meta
        let symbolic = isDir ? "drwxr-xr-x" : (meta?.symbolic ?? "-rw-r--r--")
        let owner = meta?.owner ?? "azubi"
        let group = meta?.group ?? "azubi"
        // Die Größe ist die Dateigröße in Bytes, nicht der Änderungszeitpunkt.
        let sizeText = String(file?.content.utf8.count ?? 0)
        let stamp = (meta?.modified ?? Date(timeIntervalSince1970: 0)).formattedStampUTC
        let linkCount = isDir ? 2 : 1
        return "\(symbolic) \(linkCount) \(owner) \(group) \(sizeText) \(stamp) \(name)"
    }

    private func runStat(_ args: [String]) throws -> String {
        guard let target = args.first else { throw ShellError.missingArgument("stat") }
        let path = try resolve(target)
        guard let file = fs.file(at: path) else {
            if fs.isDirectory(path) { throw ShellError.isADirectory(path) }
            throw ShellError.noSuchFile(path)
        }
        let meta = file.meta
        let bytes = file.content.utf8.count
        return """
          File: \(VPath.lastComponent(path))
          Size: \(bytes)\tBlocks: \((bytes + 511) / 512)\t\tIO Block: 4096\tregular file
        Device: 0,120\tInode: \(inode(for: path))\tLinks: 1
        Access: (\(meta.octal)/\(meta.symbolic))  Uid: (\(uid(for: meta.owner))/\(meta.owner))   Gid: (\(gid(for: meta.group))/\(meta.group))
        Modify: \(meta.modified.isoStampUTC)
        Change: \(meta.modified.isoStampUTC)
          Birth: \(meta.modified.isoStampUTC)
        """
    }

    private func runCat(_ args: [String]) throws -> String {
        let targets = args.filter { !$0.hasPrefix("-") }
        guard !targets.isEmpty else { throw ShellError.missingArgument("cat") }
        var out = ""
        for target in targets {
            let path = try resolve(target)
            if fs.isDirectory(path) { throw ShellError.isADirectory(path) }
            guard let file = fs.file(at: path) else { throw ShellError.noSuchFile(path) }
            out += file.content
            if !file.content.hasSuffix("\n") { out += "\n" }
        }
        return out
    }

    private func runGrep(_ args: [String]) throws -> String {
        var ignoreCase = false
        var showNumbers = false
        var operands: [String] = []
        for arg in args {
            if arg == "-i" { ignoreCase = true; continue }
            if arg == "-n" { showNumbers = true; continue }
            if arg.hasPrefix("-") && arg.count > 1 {
                throw ShellError.unsupportedInM1("Option \(arg)")
            }
            operands.append(arg)
        }
        guard operands.count >= 2 else { throw ShellError.missingArgument("grep") }
        let pattern = operands[0]
        let files = Array(operands.dropFirst())
        guard !pattern.isEmpty else { throw ShellError.invalidPattern(pattern) }

        var out = ""
        for target in files {
            let path = try resolve(target)
            if fs.isDirectory(path) { throw ShellError.isADirectory(path) }
            guard let file = fs.file(at: path) else { throw ShellError.noSuchFile(path) }
            var found = false
            for (index, line) in file.content.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
                let text = String(line)
                let haystack = ignoreCase ? text.lowercased() : text
                let needle = ignoreCase ? pattern.lowercased() : pattern
                if haystack.contains(needle) {
                    found = true
                    out += showNumbers ? "\(index + 1):\(text)\n" : text + "\n"
                }
            }
            if !found {
                // GNU-grep beendet sich hier mit Status 1, verändert aber nichts.
                if files.count == 1 {
                    throw ShellError.patternNotFound(pattern, file: VPath.lastComponent(path))
                }
            }
        }
        return out
    }

    private mutating func runCp(_ args: [String]) throws -> String {
        let operands = args.filter { !$0.hasPrefix("-") }
        guard operands.count >= 2 else { throw ShellError.missingArgument("cp") }
        let source = try resolve(operands[0])
        let destination = try resolve(operands[1])

        if fs.isDirectory(source) { throw ShellError.sourceIsDirectory(source) }
        guard let file = fs.file(at: source) else { throw ShellError.noSuchFile(source) }

        // Ziel ist ein existierendes Verzeichnis -> Zielname hinein.
        var targetPath = destination
        if fs.isDirectory(destination) {
            targetPath = (destination == VPath.root ? "/" : destination + "/") + VPath.lastComponent(source)
        }
        if source == targetPath { throw ShellError.sameFile(source) }
        try assertWritable(targetPath)

        // cp überschreibt den Inhalt, übernimmt aber keine Besitzer-Metadaten:
        // die Metadaten des Ziels bleiben erhalten.
        let meta = fs.file(at: targetPath)?.meta ?? defaultMeta()
        fs.setFile(VFile(content: file.content, meta: meta), at: targetPath)
        return ""
    }

    private mutating func runMkdir(_ args: [String]) throws -> String {
        let parents = args.contains("-p")
        let operands = args.filter { !$0.hasPrefix("-") }
        guard let target = operands.first else { throw ShellError.missingArgument("mkdir") }
        let path = try resolve(target)
        guard isBelegFolder(path) else { throw ShellError.writeOutsideSandbox(path) }

        if fs.isDirectory(path) {
            if parents { return "" }
            throw ShellError.permissionDenied(path)
        }
        if parents {
            let parts = path.split(separator: "/").map(String.init)
            var current = ""
            for part in parts {
                current = current.isEmpty ? "/" + part : current + "/" + part
                if current == VPath.home { fs.directories.insert(current); continue }
                fs.directories.insert(current)
            }
        } else {
            let parent = VPath.parent(of: path)
            if !fs.isDirectory(parent) { throw ShellError.noSuchDirectory(parent) }
            fs.directories.insert(path)
        }
        return ""
    }

    // MARK: Hilfsfunktionen

    private func resolve(_ target: String) throws -> String {
        guard let path = VPath.normalize(target, cwd: cwd) else {
            throw ShellError.noSuchFile(target)
        }
        return path
    }

    /// Schreibschutz: geschrieben werden darf nur
    ///
    /// 1. unter `~/belege` (bzw. `/home/azubi/belege`) – dort liegen die Belege, und
    /// 2. in bestehende Dateien, deren Rechte der Gruppe `azubi` das Schreiben
    ///    erlauben – das ist genau `kaffeekasse.csv` (0664, Gruppe azubi).
    ///
    /// Die Sicherung `kaffeekasse.bak` (root:root, 0644) bleibt geschützt,
    /// ebenso alle anderen Pfade ausserhalb des Übungsordners.
    private func assertWritable(_ path: String) throws {
        guard isWritable(path) else {
            throw ShellError.writeOutsideSandbox(VPath.display(path))
        }
    }

    private func isWritable(_ path: String) -> Bool {
        // Die Sicherung ist nie schreibbar.
        if path.hasSuffix(".bak") { return false }
        // Der Belege-Ordner gehört dem Azubi.
        if isBelegFolder(path) { return true }
        // Sonst nur bestehende Dateien, die der Gruppe azubi das Schreiben
        // erlauben – das ist die Kaffeekasse-Liste (0664, Gruppe azubi).
        guard let file = fs.file(at: path) else { return false }
        return file.meta.group == "azubi" && (file.meta.permissions & 0o020) != 0
    }

    /// true, wenn der Pfad im Belege-Ordner (oder diesem selbst) liegt.
    private func isBelegFolder(_ path: String) -> Bool {
        let belege = VPath.home + "/belege"
        return path == belege || path.hasPrefix(belege + "/")
    }

    private func defaultMeta() -> FileMeta {
        FileMeta(owner: "azubi", group: "azubi", permissions: 0o644, modified: Date())
    }

    private func inode(for path: String) -> Int {
        abs(path.hashValue % 9000) + 1000
    }

    private func uid(for owner: String) -> Int {
        switch owner {
        case "root": return 0
        case "kaffee": return 1001
        default: return 1000
        }
    }

    private func gid(for group: String) -> Int {
        switch group {
        case "root": return 0
        case "azubi": return 1001
        default: return 1001
        }
    }

    private func helpText() -> String {
        """
        Unterstützte Befehle in dieser Übung:
          pwd                      aktuelles Verzeichnis anzeigen
          cd <pfad>                Verzeichnis wechseln (~, ., .. und absolute Pfade)
          ls [pfad]                Dateien auflisten
          ls -l <pfad>             Dateien mit Besitzer, Rechten und Datum auflisten
          stat <datei>            Besitzer, Rechte und Zeitstempel anzeigen
          cat <datei...>          Dateiinhalt anzeigen
          grep [-i] <muster> <datei...>   Zeilen mit Muster anzeigen
          cp <quelle> <ziel>      Datei kopieren (überschreibt Inhalt)
          mkdir [-p] <pfad>       Verzeichnis anlegen (nur unter ~/belege)
          help                    diese Übersicht
          clear                   Bildschirm leeren

        Umleitung:  befehl > datei   (ersetzt)
                    befehl >> datei  (hängt an)
        Pfade:      ~/belege, /srv/rechenwerk/uebung, /home/azubi/belege
        Hinweis:    Das ist eine lokale Übungssimulation. Es laufen keine Befehle
                    auf deinem Mac, es gibt keine echte Linux-VM und kein Netzwerk.
        """
    }
}

/// Ergebnis eines Shell-Aufrufs.
public struct ShellResult: Sendable, Equatable {
    public var output: String
    public var isError: Bool
    public var redirectTarget: String?

    public init(output: String, isError: Bool, redirectTarget: String? = nil) {
        self.output = output
        self.isError = isError
        self.redirectTarget = redirectTarget
    }
}

// MARK: - Datumsformatierung

extension Date {
    /// `2026-04-17 03:12` (UTC) – wie `ls -l` bei UTC-System.
    var formattedStampUTC: String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: self)
        return String(format: "%04d-%02d-%02d %02d:%02d",
                      parts.year ?? 0, parts.month ?? 0, parts.day ?? 0,
                      parts.hour ?? 0, parts.minute ?? 0)
    }

    /// `2026-04-17 03:12:00.000000000 +0000` – wie `stat`.
    var isoStampUTC: String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: self)
        return String(format: "%04d-%02d-%02d %02d:%02d:%02d.000000000 +0000",
                      parts.year ?? 0, parts.month ?? 0, parts.day ?? 0,
                      parts.hour ?? 0, parts.minute ?? 0, parts.second ?? 0)
    }
}
