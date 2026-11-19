// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "StaffelZwei",
    platforms: [.macOS(.v15)],
    dependencies: [
        .package(url: "https://github.com/migueldeicaza/SwiftTerm.git", exact: "1.11.2"),
    ],
    targets: [
        // Reine Logik ohne SwiftUI/AppKit: Tests laufen schnell und ohne App.
        .target(name: "StaffelCore", resources: [.copy("Resources/Missions.json")]),
        .executableTarget(
            name: "StaffelZwei",
            dependencies: ["StaffelCore", .product(name: "SwiftTerm", package: "SwiftTerm")],
            swiftSettings: [.defaultIsolation(MainActor.self)]
        ),
        .testTarget(name: "StaffelCoreTests", dependencies: ["StaffelCore"]),
    ]
)
