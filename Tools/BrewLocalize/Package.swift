// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "BrewLocalize",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "brew-localize", targets: ["brew-localize"]),
    ],
    targets: [
        .target(name: "BrewLocalizeCore"),
        .executableTarget(
            name: "brew-localize",
            dependencies: ["BrewLocalizeCore"],
        ),
        .testTarget(
            name: "BrewLocalizeCoreTests",
            dependencies: ["BrewLocalizeCore"],
        ),
    ],
)
