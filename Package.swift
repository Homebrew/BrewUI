// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "BrewUI",
    platforms: [
        .macOS("26.0"),
    ],
    products: [
        .library(name: "BrewCore", targets: ["BrewCore"]),
        .library(name: "BrewDesignSystem", targets: ["BrewDesignSystem"]),
        .library(name: "BrewCLI", targets: ["BrewCLI"]),
    ],
    targets: [
        .target(
            name: "BrewCore",
            swiftSettings: [
                .defaultIsolation(nil),
                .swiftLanguageMode(.v6),
            ],
        ),
        .target(
            name: "BrewDesignSystem",
            dependencies: ["BrewCore"],
            resources: [
                .process("Resources/Media.xcassets"),
            ],
            swiftSettings: [
                .defaultIsolation(MainActor.self),
                .swiftLanguageMode(.v6),
            ],
        ),
        .target(
            name: "BrewCLI",
            dependencies: ["BrewCore"],
            swiftSettings: [
                .defaultIsolation(nil),
                .swiftLanguageMode(.v6),
            ],
        ),
    ],
)
