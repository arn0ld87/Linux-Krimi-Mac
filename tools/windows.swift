#!/usr/bin/env swift
// Lists the on-screen windows of one app, so an agent can address a single
// window for a capture (screencapture -l <number>).
//
// Usage: swift tools/windows.swift [app-name-filter]
//        swift tools/windows.swift --pid <pid>
//
// --pid is the safe way to address a window: it lists only the windows of
// one process, so a second instance of the same app cannot be mistaken for
// the one under test. Never take "the first window of the app".
import CoreGraphics
import Foundation

var filter = ""
var pidFilter: Int?
var arguments = Array(CommandLine.arguments.dropFirst())
while let index = arguments.firstIndex(of: "--pid") {
    guard index + 1 < arguments.count, let value = Int(arguments[index + 1]) else {
        print("FAIL windows: --pid needs a number")
        exit(2)
    }
    pidFilter = value
    arguments.removeSubrange(index...(index + 1))
}
if let first = arguments.first { filter = first.lowercased() }

// Ohne optionOnScreenOnly: bei schlafendem Display meldet der Window Server
// keine Fenster als "on screen", obwohl sie existieren.
let options: CGWindowListOption = [.excludeDesktopElements]
let windows = (CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]]) ?? []
for window in windows {
    let owner = window[kCGWindowOwnerName as String] as? String ?? ""
    let pid = window[kCGWindowOwnerPID as String] as? Int ?? -1
    if let pidFilter, pid != pidFilter { continue }
    if !filter.isEmpty && !owner.lowercased().contains(filter) { continue }
    let number = window[kCGWindowNumber as String] as? Int ?? -1
    let layer = window[kCGWindowLayer as String] as? Int ?? -1
    let name = window[kCGWindowName as String] as? String ?? ""
    let bounds = window[kCGWindowBounds as String] as? [String: Any] ?? [:]
    let width = bounds["Width"] as? Int ?? 0
    let height = bounds["Height"] as? Int ?? 0
    let onscreen = window[kCGWindowIsOnscreen as String] as? Bool ?? false
    print("pid=\(pid) window=\(number) layer=\(layer) onscreen=\(onscreen) size=\(width)x\(height) name=\"\(name)\" owner=\(owner)")
}
