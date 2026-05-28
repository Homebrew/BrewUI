// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "BrewUI",
    platforms: [
        .macOS("26.0"),
    ],
    products: [
        .library(name: "BrewCore", targets: ["BrewCore"]),
    ],
    targets: [
        .target(
            name: "BrewCore",
            swiftSettings: [
                .defaultIsolation(nil),
                .swiftLanguageMode(.v6),
            ],
        ),
    ],
)
