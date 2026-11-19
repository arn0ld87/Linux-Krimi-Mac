#!/usr/bin/env swift
// Checks the layout files that snapshot mode writes next to each PNG.
// Usage: swift tools/check-layout.swift [--unit 4] /tmp/StaffelZwei-shots/*-layout.json
// --unit sets the grid step for rules 2 and 5. A design kit measured from
// another app keeps that app's numbers: pass its step, or 0.5 to check only
// edges, insets, and overlaps.
//
// --require-matrix <dir> validates every required page in Light and Dark.
//
// Rules, for views marked with .gridArea and .gridProbe (UI/Grid.swift):
//   1. Every view starts on a whole or half point across, so edges stay sharp.
//      (Heights of text have fractions, so y is checked through the gaps in rule 5.)
//   2. A probe starts a multiple of the unit (4 pt) from its area's leading edge.
//   3. A probe stays at least the area's inset from both sides.
//   4. Probes with the same area and edge share one leading edge.
//   5. Stacked probes on one edge are a multiple of the unit apart. Text heights
//      have fractions and SwiftUI rounds positions, so gaps get 0.5 pt of room.
//   6. Probes in one area never overlap.
//   7. Probes whose edge starts with "=" line up across areas, and rules 2 to 6 skip them:
//      "=name" same left and right, "=name<" same left, "=name>" same right,
//      "=name|" same center, "=name_" same bottom.
// Prints PASS or FAIL per file and exits with 1 on any failure.
// Exits 2 when the call itself is wrong (no files, unknown option).
import Foundation
struct Probe: Decodable {
    var kind: String
    var name: String
    var area: String
    var edge: String?
    var inset: Double
    var x: Double
    var y: Double
    var width: Double
    var height: Double
    var maxX: Double { x + width }
    var maxY: Double { y + height }
}
struct LayoutFile: Decodable {
    var window: [String: Double]?
    var probes: [Probe]
}
/// The pages the app shows, in the order of AppPage.
let matrixPages = ["briefing", "terminal", "aktenwand", "vorwurf", "help"]
let matrixModes = ["light", "dark"]
let tolerance = 0.26
let gapTolerance = 0.51
let pixelTolerance = 0.05
func onGrid(_ value: Double, step: Double, within: Double = tolerance) -> Bool {
    let rest = value.truncatingRemainder(dividingBy: step)
    return abs(rest) < within || abs(abs(rest) - step) < within
}
func fmt(_ value: Double) -> String { String(format: "%g", value) }
func isFiniteNumber(_ value: Double) -> Bool { value.isFinite }
var arguments = Array(CommandLine.arguments.dropFirst())
var unit = 4.0
var matrixDirectory: String?
while let index = arguments.firstIndex(where: { $0.hasPrefix("--") }) {
    let option = arguments[index]
    switch option {
    case "--unit":
        guard index + 1 < arguments.count, let value = Double(arguments[index + 1]),
              value > 0 else {
            print("FAIL check-layout: --unit needs a positive number")
            exit(2)
        }
        unit = value
        arguments.removeSubrange(index...(index + 1))
    case "--require-matrix":
        guard matrixDirectory == nil, index + 1 < arguments.count,
              !arguments[index + 1].hasPrefix("--") else {
            print("FAIL check-layout: --require-matrix needs exactly one directory")
            exit(2)
        }
        matrixDirectory = arguments[index + 1]
        arguments.removeSubrange(index...(index + 1))
    default:
        print("FAIL check-layout: unknown option \(option)")
        exit(2)
    }
}
let requiredPaths = matrixDirectory.map { directory in
    matrixPages.flatMap { page in
        matrixModes.map { mode in
            URL(fileURLWithPath: directory, isDirectory: true)
                .appendingPathComponent("\(page)-\(mode)-layout.json").standardizedFileURL.path
        }
    }
} ?? []
let required = Set(requiredPaths)
var seen: Set<String> = []
let paths = (requiredPaths + arguments).map {
    URL(fileURLWithPath: $0).standardizedFileURL.path
}.filter { seen.insert($0).inserted }
// Without files there is nothing to check: that is a failed check, not a pass.
if paths.isEmpty {
    print("FAIL check-layout: no layout files given")
    exit(2)
}
var failedFiles = 0
var validRequiredFiles = 0
for path in paths {
    if required.contains(path) {
        let values = try? URL(fileURLWithPath: path).resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
        guard values?.isRegularFile == true, values?.isSymbolicLink == false else {
            print("FAIL \(path): missing or not a regular matrix file")
            failedFiles += 1
            continue
        }
    }
    guard let data = FileManager.default.contents(atPath: path),
          let file = try? JSONDecoder().decode(LayoutFile.self, from: data) else {
        print("FAIL \(path): cannot read")
        failedFiles += 1
        continue
    }
    var problems: [String] = []
    // The window the probes belong to must have a real size.
    if let window = file.window {
        for key in ["width", "height"] {
            guard let value = window[key], isFiniteNumber(value), value > 0 else {
                problems.append("window \(key) is not a positive number")
                continue
            }
        }
    }
    // A file without probes proves nothing.
    guard !file.probes.isEmpty else {
        problems.append("no probes in file")
        print("FAIL \((path as NSString).lastPathComponent)")
        for problem in problems { print("  - \(problem)") }
        failedFiles += 1
        continue
    }
    let areas = Dictionary(file.probes.filter { $0.kind == "area" }.map { ($0.area, $0) },
                           uniquingKeysWith: { first, _ in first })
    let probes = file.probes.filter { $0.kind == "probe" && !($0.edge ?? "").hasPrefix("=") }
    if !file.probes.contains(where: { $0.kind == "probe" }) {
        problems.append("no view probes in file")
    }
    // Every probe and every area needs real, finite, positive geometry.
    for probe in file.probes {
        let label = "\(probe.kind) '\(probe.name)'"
        if probe.kind != "area" && probe.kind != "probe" {
            problems.append("\(label): unknown kind")
        }
        for (what, value) in [("x", probe.x), ("y", probe.y),
                              ("width", probe.width), ("height", probe.height),
                              ("inset", probe.inset)] {
            if !isFiniteNumber(value) {
                problems.append("\(label): \(what) is not a finite number")
            }
        }
        if probe.width <= 0 { problems.append("\(label): width is not positive") }
        if probe.height <= 0 { problems.append("\(label): height is not positive") }
        if probe.inset < 0 { problems.append("\(label): inset is negative") }
    }
    for (name, area) in areas where area.width <= 0 || area.height <= 0 {
        problems.append("area '\(name)' has no positive size")
    }
    let shared = Dictionary(grouping: file.probes.filter { ($0.edge ?? "").hasPrefix("=") }) { $0.edge! }
    for (edge, group) in shared.sorted(by: { $0.key < $1.key }) where group.count > 1 {
        func differ(_ what: String, _ value: (Probe) -> Double) {
            let low = group.map(value).min()!, high = group.map(value).max()!
            if high - low > tolerance {
                let list = group.map { "\($0.name) \(fmt(value($0)))" }.joined(separator: ", ")
                problems.append("\(edge) has different \(what): \(list)")
            }
        }
        switch edge.last {
        case "<": differ("left edges") { $0.x }
        case ">": differ("right edges") { $0.maxX }
        case "|": differ("centers") { $0.x + $0.width / 2 }
        case "_": differ("bottoms") { $0.maxY }
        default:
            differ("left edges") { $0.x }
            differ("right edges") { $0.maxX }
        }
    }
    for probe in file.probes where probe.width > 0 {
        if !onGrid(probe.x, step: 0.5, within: pixelTolerance) {
            problems.append("\(probe.name): x \(fmt(probe.x)) is between pixels")
        }
    }
    for probe in probes {
        guard let area = areas[probe.area] else {
            problems.append("\(probe.name): area \"\(probe.area)\" has no .gridArea")
            continue
        }
        let lead = probe.x - area.x
        if !onGrid(lead, step: unit) {
            problems.append("\(probe.name): starts \(fmt(lead)) pt into \(area.name), not a multiple of \(fmt(unit))")
        }
        if lead < area.inset - tolerance {
            problems.append("\(probe.name): starts \(fmt(lead)) pt into \(area.name), inside its \(fmt(area.inset)) pt inset")
        }
        let trail = area.maxX - probe.maxX
        if trail < area.inset - tolerance {
            problems.append("\(probe.name): ends \(fmt(trail)) pt from the right of \(area.name), inside its \(fmt(area.inset)) pt inset")
        }
    }
    let edges = Dictionary(grouping: probes.filter { $0.edge != nil }) { "\($0.area)/\($0.edge!)" }
    for (key, group) in edges.sorted(by: { $0.key < $1.key }) {
        let xs = Set(group.map { ($0.x * 2).rounded() / 2 })
        if xs.count > 1 {
            let list = group.map { "\($0.name) \(fmt($0.x))" }.joined(separator: ", ")
            problems.append("edge \(key) has \(xs.count) leading edges: \(list)")
        }
        let stacked = group.sorted { $0.y < $1.y }
        for (above, below) in zip(stacked, stacked.dropFirst()) where below.y >= above.maxY - tolerance {
            let gap = below.y - above.maxY
            if !onGrid(gap, step: unit, within: min(gapTolerance, unit / 2 - 0.01)) {
                problems.append("\(above.name) to \(below.name): gap \(fmt(gap)) pt, not a multiple of \(fmt(unit))")
            }
        }
    }
    for (area, group) in Dictionary(grouping: probes, by: \.area) {
        for (index, first) in group.enumerated() {
            for second in group.dropFirst(index + 1) {
                let overlapX = min(first.maxX, second.maxX) - max(first.x, second.x)
                let overlapY = min(first.maxY, second.maxY) - max(first.y, second.y)
                if overlapX > tolerance && overlapY > tolerance {
                    problems.append("\(first.name) and \(second.name) overlap in \(area)")
                }
            }
        }
    }
    let name = (path as NSString).lastPathComponent
    if problems.isEmpty {
        if required.contains(path) { validRequiredFiles += 1 }
        print("PASS \(name): \(probes.count) probes in \(areas.count) areas, \(shared.values.joined().count) lined up across areas")
    } else {
        failedFiles += 1
        print("FAIL \(name)")
        for problem in problems { print("  - \(problem)") }
    }
}
if let directory = matrixDirectory {
    if validRequiredFiles == requiredPaths.count {
        print("PASS matrix \(directory): \(validRequiredFiles) screen layouts")
    } else {
        print("FAIL matrix \(directory): \(validRequiredFiles) of \(requiredPaths.count) valid screen layouts")
    }
}
exit(failedFiles == 0 ? 0 : 1)
