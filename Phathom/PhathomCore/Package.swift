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
    targets: [
        .target(
            name: "PhathomCore",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency"),
            ]
        ),
    ]
)
