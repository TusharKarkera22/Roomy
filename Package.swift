// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Roomy",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "RoomyCore", resources: [.copy("rules.json")]),
        .executableTarget(name: "Roomy", dependencies: ["RoomyCore"]),
        .testTarget(name: "RoomyCoreTests", dependencies: ["RoomyCore"]),
    ],
    swiftLanguageModes: [.v5]
)
