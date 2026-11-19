import Foundation

// MARK: - Pfade

/// Normalisierung virtueller Linux-Pfade.
///
/// Regeln: `~` -> Home, `.` und `..` werden aufgelöst, relative Pfade werden
/// gegen das aktuelle Arbeitsverzeichnis gelöst. Ergebnis ist immer absolut
/// und ohne trailing slash (ausser Root).
public enum VPath {
    public static let root = "/"
    public static let home = "/home/azubi"

    /// Normalisiert `raw` gegen `cwd`. `~` wird durch `home` ersetzt.
    ///
    /// `~/pfad` löst immer gegen das Home-Verzeichnis auf, unabhängig vom
    /// aktuellen Arbeitsverzeichnis. Relative Pfade lösen gegen `cwd` auf.
    /// Gibt nil zurück, wenn das Ergebnis ausserhalb des Dateisystems läge
    /// (hier nicht möglich, aber die Signatur bleibt zukunftssicher).
    public static func normalize(_ raw: String, cwd: String = home, home: String = VPath.home) -> String? {
        var p = raw.trimmingCharacters(in: .whitespaces)
        guard !p.isEmpty else { return cwd }

        if p == "~" { return home }

        var stack: [String]
        if p.hasPrefix("~/") {
            // Home ist eine absolute Basis – der Rest darf nicht relativ zum
            // aktuellen Verzeichnis aufgelöst werden.
            p = String(p.dropFirst(2))
            stack = home.split(separator: "/").map(String.init)
        } else if p.hasPrefix("/") {
            stack = []
        } else {
            stack = cwd.split(separator: "/").map(String.init)
        }

        for part in p.split(separator: "/", omittingEmptySubsequences: true) {
            switch part {
            case ".":
                continue
            case "..":
                if !stack.isEmpty { stack.removeLast() }
            default:
                stack.append(String(part))
            }
        }
        let joined = stack.joined(separator: "/")
        return joined.isEmpty ? root : "/" + joined
    }

    /// Anzeigename eines Pfades: Home wird zu `~`.
    public static func display(_ path: String, home: String = VPath.home) -> String {
        if path == home { return "~" }
        if path.hasPrefix(home + "/") { return "~" + path.dropFirst(home.count) }
        return path
    }

    /// Elternverzeichnis eines absoluten Pfads.
    public static func parent(of path: String) -> String {
        guard path != root else { return root }
        let parts = path.split(separator: "/").map(String.init)
        guard parts.count > 1 else { return root }
        return "/" + parts.dropLast().joined(separator: "/")
    }

    /// Letzte Komponente eines Pfads.
    public static func lastComponent(_ path: String) -> String {
        path.split(separator: "/").last.map(String.init) ?? path
    }
}

// MARK: - Dateien und Metadaten

/// Besitzer, Gruppe, Rechte und Zeitstempel einer Datei.
public struct FileMeta: Codable, Sendable, Equatable {
    public var owner: String
    public var group: String
    /// Oktale Rechte, z. B. 0o664.
    public var permissions: Int
    public var modified: Date

    public init(owner: String, group: String, permissions: Int, modified: Date) {
        self.owner = owner
        self.group = group
        self.permissions = permissions
        self.modified = modified
    }

    /// Rechte im GNU-Format, z. B. `-rw-rw-r--`.
    public var symbolic: String {
        let type = "-"
        let bits = [
            (0o400, "r"), (0o200, "w"), (0o100, "x"),
            (0o040, "r"), (0o020, "w"), (0o010, "x"),
            (0o004, "r"), (0o002, "w"), (0o001, "x"),
        ]
        var out = type
        for (mask, ch) in bits {
            out.append(permissions & mask != 0 ? ch : "-")
        }
        return out
    }

    /// Rechte als oktale Viererzahl, z. B. `0664` (wie GNU `stat`).
    public var octal: String { String(format: "%04o", permissions) }
}

/// Eine Datei im virtuellen Dateisystem.
public struct VFile: Codable, Sendable, Equatable {
    public var content: String
    public var meta: FileMeta

    public init(content: String, meta: FileMeta) {
        self.content = content
        self.meta = meta
    }
}

/// Deterministische In-Memory-Dateiwelt des Übungsterminals.
public struct VirtualFS: Codable, Sendable, Equatable {
    /// Absolute Pfade -> Datei.
    public var files: [String: VFile]
    /// Absolute Verzeichnispfade.
    public var directories: Set<String>

    public init(files: [String: VFile] = [:], directories: Set<String> = []) {
        self.files = files
        self.directories = directories
    }

    public func file(at path: String) -> VFile? { files[path] }

    public mutating func setFile(_ file: VFile, at path: String) {
        files[path] = file
    }

    public func exists(at path: String) -> Bool {
        files[path] != nil || directories.contains(path)
    }

    public func isDirectory(_ path: String) -> Bool { directories.contains(path) }

    /// Alle direkten Kinder eines Verzeichnisses, sortiert nach Name.
    public func children(of path: String) -> [(name: String, path: String, isDir: Bool)] {
        let prefix = path == VPath.root ? "/" : path + "/"
        var names: Set<String> = []
        for candidate in files.keys where candidate.hasPrefix(prefix) {
            let rest = candidate.dropFirst(prefix.count)
            if let slash = rest.firstIndex(of: "/") {
                names.insert(String(rest[..<slash]))
            } else if !rest.isEmpty {
                names.insert(String(rest))
            }
        }
        for candidate in directories where candidate.hasPrefix(prefix) {
            let rest = candidate.dropFirst(prefix.count)
            if let slash = rest.firstIndex(of: "/") {
                names.insert(String(rest[..<slash]))
            } else if !rest.isEmpty {
                names.insert(String(rest))
            }
        }
        return names.sorted().map { name in
            let full = prefix + name
            return (name, full, directories.contains(full))
        }
    }
}
