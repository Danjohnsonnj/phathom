// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PhathomCore",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "PhathomCore", targets: ["PhathomCore"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-markdown", from: "0.5.0"),
    ],
    targets: [
        .target(
            name: "PhathomCore",
            dependencies: [
                .product(name: "Markdown", package: "swift-markdown"),
            ],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency"),
            ]
        ),
        .testTarget(
            name: "PhathomCoreTests",
            dependencies: ["PhathomCore"]
        ),
    ]
)
