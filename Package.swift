// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "BrewKit",
    platforms: [
        .macOS("26.0"),
    ],
    products: [
        .library(name: "BrewAccessibilityID", targets: ["BrewAccessibilityID"]),
        .library(name: "BrewUITestContract", targets: ["BrewUITestContract"]),
        .library(name: "BrewCore", targets: ["BrewCore"]),
        .library(name: "BrewCrashReporting", targets: ["BrewCrashReporting"]),
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
        .library(name: "BrewFeatureDoctor", targets: ["BrewFeatureDoctor"]),
        .library(name: "BrewFeatureConfig", targets: ["BrewFeatureConfig"]),
    ],
    dependencies: [
        // Justification (`CONVENTIONS.md` — Dependencies): running `brew` under a pseudo-terminal needs
        // `setsid()` between fork and exec so the pty becomes the child's *controlling* terminal.
        // `Foundation.Process` has no hook there and structurally cannot express it; `Subprocess` exposes it as
        // `PlatformOptions.createSession`, along with the fd hand-off and process-group teardown the pty path
        // needs. Confined to `BrewCLI` behind the `BrewCommandRunning` protocol, so it has exactly one conformer.
        // Version pinned exactly, per the same convention.
        .package(url: "https://github.com/swiftlang/swift-subprocess.git", exact: "1.0.0"),
    ],
    targets: [
        // Dependency-free by design: linked by both the app and the BrewUITests target, so it must
        // not drag app code into the test bundle.
        .target(
            name: "BrewAccessibilityID",
            swiftSettings: [
                .defaultIsolation(nil),
                .swiftLanguageMode(.v6),
            ],
        ),
        // Dependency-free for the same reason as BrewAccessibilityID: the BrewUITests target links it,
        // so it must not drag app code into the test bundle. Holds the launch contract — the
        // environment key names and the fixture payload — so both sides spell them once.
        .target(
            name: "BrewUITestContract",
            swiftSettings: [
                .defaultIsolation(nil),
                .swiftLanguageMode(.v6),
            ],
        ),
        .target(
            name: "BrewCore",
            swiftSettings: [
                .defaultIsolation(nil),
                .swiftLanguageMode(.v6),
            ],
        ),
        .target(
            name: "BrewCrashReporting",
            swiftSettings: [
                .defaultIsolation(nil),
                .swiftLanguageMode(.v6),
            ],
        ),
        .target(
            name: "BrewUIComponents",
            dependencies: ["BrewAccessibilityID", "BrewCore"],
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
            dependencies: [
                "BrewCore",
                .product(name: "Subprocess", package: "swift-subprocess"),
            ],
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
                "BrewAccessibilityID",
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
                "BrewAccessibilityID",
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
                "BrewAccessibilityID",
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
            name: "BrewFeatureDoctor",
            dependencies: [
                "BrewAccessibilityID",
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
            name: "BrewFeatureConfig",
            dependencies: [
                "BrewAccessibilityID",
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
            name: "BrewAccessibilityIDTests",
            dependencies: ["BrewAccessibilityID"],
            swiftSettings: [
                .defaultIsolation(nil),
                .swiftLanguageMode(.v6),
            ],
        ),
        .testTarget(
            name: "BrewCrashReportingTests",
            dependencies: ["BrewCrashReporting"],
            swiftSettings: [
                .defaultIsolation(nil),
                .swiftLanguageMode(.v6),
            ],
        ),
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
                "BrewRepositories",
                "BrewNetworking",
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
        .testTarget(
            name: "BrewFeatureDoctorTests",
            dependencies: [
                "BrewFeatureDoctor",
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
        .testTarget(
            name: "BrewFeatureConfigTests",
            dependencies: [
                "BrewFeatureConfig",
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
    ],
)
