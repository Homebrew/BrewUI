// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "BrewKit",
    platforms: [
        .macOS("26.0"),
    ],
    products: [
        .library(name: "BrewCore", targets: ["BrewCore"]),
        .library(name: "BrewUIComponents", targets: ["BrewUIComponents"]),
        .library(name: "BrewCLI", targets: ["BrewCLI"]),
        .library(name: "BrewNetworking", targets: ["BrewNetworking"]),
        .library(name: "BrewRepositoryInterfaces", targets: ["BrewRepositoryInterfaces"]),
        .library(name: "BrewRepositories", targets: ["BrewRepositories"]),
        .library(name: "BrewAppEnvironment", targets: ["BrewAppEnvironment"]),
        .library(name: "BrewCoreTestSupport", targets: ["BrewCoreTestSupport"]),
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
            name: "BrewUIComponents",
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
            name: "BrewRepositoryInterfaces",
            dependencies: ["BrewCore"],
            swiftSettings: [
                .defaultIsolation(nil),
                .swiftLanguageMode(.v6),
            ],
        ),
        .target(
            name: "BrewRepositories",
            dependencies: ["BrewRepositoryInterfaces", "BrewCLI", "BrewNetworking"],
            swiftSettings: [
                .defaultIsolation(nil),
                .swiftLanguageMode(.v6),
            ],
        ),
        .target(
            name: "BrewAppEnvironment",
            dependencies: ["BrewCore", "BrewRepositoryInterfaces"],
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
            name: "BrewServicesTestSupport",
            dependencies: [
                "BrewCore",
                "BrewCLI",
                "BrewNetworking",
                "BrewRepositoryInterfaces",
                "BrewRepositories",
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
                "BrewUIComponents",
                "BrewRepositoryInterfaces",
                "BrewAppEnvironment",
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
                "BrewUIComponents",
                "BrewRepositoryInterfaces",
                "BrewAppEnvironment",
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
                "BrewUIComponents",
                "BrewRepositoryInterfaces",
                "BrewAppEnvironment",
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
        .testTarget(
            name: "BrewCLITests",
            dependencies: ["BrewCLI", "BrewCoreTestSupport", "BrewServicesTestSupport"],
            swiftSettings: [
                .defaultIsolation(nil),
                .swiftLanguageMode(.v6),
            ],
        ),
        .testTarget(
            name: "BrewNetworkingTests",
            dependencies: ["BrewNetworking", "BrewCoreTestSupport"],
            swiftSettings: [
                .defaultIsolation(nil),
                .swiftLanguageMode(.v6),
            ],
        ),
        .testTarget(
            name: "BrewRepositoriesTests",
            dependencies: [
                "BrewRepositories",
                "BrewCore",
                "BrewCLI",
                "BrewNetworking",
                "BrewRepositoryInterfaces",
                "BrewCoreTestSupport",
                "BrewServicesTestSupport",
            ],
            swiftSettings: [
                .defaultIsolation(MainActor.self),
                .swiftLanguageMode(.v6),
            ],
        ),
        .testTarget(
            name: "BrewUIComponentsTests",
            dependencies: ["BrewUIComponents", "BrewCore"],
            swiftSettings: [
                .defaultIsolation(MainActor.self),
                .swiftLanguageMode(.v6),
            ],
        ),
        .testTarget(
            name: "BrewFeatureConsoleTests",
            dependencies: [
                "BrewFeatureConsole",
                "BrewCore",
                "BrewRepositoryInterfaces",
                "BrewRepositories",
                "BrewCoreTestSupport",
                "BrewServicesTestSupport",
            ],
            swiftSettings: [
                .defaultIsolation(MainActor.self),
                .swiftLanguageMode(.v6),
            ],
        ),
        .testTarget(
            name: "BrewFeatureDiscoverTests",
            dependencies: [
                "BrewFeatureDiscover",
                "BrewCLI",
                "BrewCore",
                "BrewRepositoryInterfaces",
                "BrewCoreTestSupport",
                "BrewServicesTestSupport",
            ],
            swiftSettings: [
                .defaultIsolation(MainActor.self),
                .swiftLanguageMode(.v6),
            ],
        ),
        .testTarget(
            name: "BrewFeatureInstalledTests",
            dependencies: [
                "BrewFeatureInstalled",
                "BrewCLI",
                "BrewCore",
                "BrewUIComponents",
                "BrewRepositoryInterfaces",
                "BrewRepositories",
                "BrewCoreTestSupport",
                "BrewServicesTestSupport",
            ],
            swiftSettings: [
                .defaultIsolation(MainActor.self),
                .swiftLanguageMode(.v6),
            ],
        ),
    ],
)
