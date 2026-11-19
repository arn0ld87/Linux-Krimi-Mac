// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "StaffelZwei",
    platforms: [.macOS(.v15)],
    targets: [
        // Reine Logik ohne SwiftUI/AppKit: Tests laufen schnell und ohne App.
        .target(name: "StaffelCore", resources: [.copy("Resources/Missions.json")]),
        .executableTarget(
            name: "StaffelZwei",
            dependencies: ["StaffelCore"],
            swiftSettings: [.defaultIsolation(MainActor.self)]
        ),
        .testTarget(name: "StaffelCoreTests", dependencies: ["StaffelCore"]),
    ]
)
