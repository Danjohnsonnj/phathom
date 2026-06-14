// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "PhathomCore",
    platforms: [
        .iOS(.v17),
        .macOS(.v26),
    ],
    products: [
        .library(name: "PhathomCore", targets: ["PhathomCore", "PhathomCoreMarkdown"]),
        .library(name: "PhathomShareCore", targets: ["PhathomCore"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-markdown", from: "0.5.0"),
    ],
    targets: [
        .target(
            name: "PhathomCore",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency"),
            ]
        ),
        .target(
            name: "PhathomCoreMarkdown",
            dependencies: [
                "PhathomCore",
                .product(name: "Markdown", package: "swift-markdown"),
            ],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency"),
            ]
        ),
        .testTarget(
            name: "PhathomCoreTests",
            dependencies: ["PhathomCore", "PhathomCoreMarkdown"]
        ),
    ]
)
