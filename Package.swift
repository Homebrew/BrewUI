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
        .library(name: "BrewNetworking", targets: ["BrewNetworking"]),
        .library(name: "BrewRepositories", targets: ["BrewRepositories"]),
        .library(name: "BrewRepositoriesLive", targets: ["BrewRepositoriesLive"]),
        .library(name: "BrewCoreTestSupport", targets: ["BrewCoreTestSupport"]),
        .library(name: "BrewRepositoriesTestSupport", targets: ["BrewRepositoriesTestSupport"]),
        .library(name: "BrewServicesTestSupport", targets: ["BrewServicesTestSupport"]),
        .library(name: "BrewFeatureConsole", targets: ["BrewFeatureConsole"]),
        .library(name: "BrewFeatureInstalled", targets: ["BrewFeatureInstalled"]),
        .library(name: "BrewFeatureDiscover", targets: ["BrewFeatureDiscover"]),
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
        .target(
            name: "BrewNetworking",
            dependencies: ["BrewCore"],
            swiftSettings: [
                .defaultIsolation(nil),
                .swiftLanguageMode(.v6),
            ],
        ),
        .target(
            name: "BrewRepositories",
            dependencies: ["BrewCore"],
            swiftSettings: [
                .defaultIsolation(MainActor.self),
                .swiftLanguageMode(.v6),
            ],
        ),
        .target(
            name: "BrewRepositoriesLive",
            dependencies: ["BrewRepositories", "BrewCLI", "BrewNetworking"],
            swiftSettings: [
                .defaultIsolation(MainActor.self),
                .swiftLanguageMode(.v6),
            ],
        ),
        .target(
            name: "BrewCoreTestSupport",
            dependencies: ["BrewCore"],
            swiftSettings: [
                .defaultIsolation(nil),
                .swiftLanguageMode(.v6),
            ],
        ),
        .target(
            name: "BrewRepositoriesTestSupport",
            dependencies: ["BrewRepositories", "BrewCoreTestSupport"],
            swiftSettings: [
                .defaultIsolation(MainActor.self),
                .swiftLanguageMode(.v6),
            ],
        ),
        .target(
            name: "BrewServicesTestSupport",
            dependencies: [
                "BrewCore",
                "BrewCLI",
                "BrewNetworking",
                "BrewRepositories",
                "BrewRepositoriesLive",
                "BrewCoreTestSupport",
            ],
            swiftSettings: [
                .defaultIsolation(nil),
                .swiftLanguageMode(.v6),
            ],
        ),
        .target(
            name: "BrewFeatureConsole",
            dependencies: [
                "BrewCore",
                "BrewDesignSystem",
                "BrewRepositories",
                "BrewRepositoriesTestSupport",
            ],
            swiftSettings: [
                .defaultIsolation(MainActor.self),
                .swiftLanguageMode(.v6),
            ],
        ),
        .target(
            name: "BrewFeatureInstalled",
            dependencies: [
                "BrewCore",
                "BrewDesignSystem",
                "BrewRepositories",
                "BrewRepositoriesTestSupport",
            ],
            swiftSettings: [
                .defaultIsolation(MainActor.self),
                .swiftLanguageMode(.v6),
            ],
        ),
        .target(
            name: "BrewFeatureDiscover",
            dependencies: [
                "BrewCore",
                "BrewDesignSystem",
                "BrewRepositories",
                "BrewRepositoriesTestSupport",
            ],
            swiftSettings: [
                .defaultIsolation(MainActor.self),
                .swiftLanguageMode(.v6),
            ],
        ),

        // MARK: - Test targets

        .testTarget(
            name: "BrewCoreTests",
            dependencies: ["BrewCore", "BrewCoreTestSupport"],
            swiftSettings: [
                .defaultIsolation(MainActor.self),
                .swiftLanguageMode(.v6),
            ],
        ),
    ],
)
