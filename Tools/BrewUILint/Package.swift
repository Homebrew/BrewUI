// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "BrewUILint",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "BrewUILint", targets: ["BrewUILint"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-syntax.git", exact: "602.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "BrewUILint",
            dependencies: [
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftParser", package: "swift-syntax"),
            ],
        ),
        .testTarget(
            name: "BrewUILintTests",
            dependencies: ["BrewUILint"],
        ),
    ],
)
