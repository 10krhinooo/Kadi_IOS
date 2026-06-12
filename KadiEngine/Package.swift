// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "KadiEngine",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "KadiEngine",
            targets: ["KadiEngine"]
        ),
    ],
    targets: [
        .target(
            name: "KadiEngine"
        ),
        .testTarget(
            name: "KadiEngineTests",
            dependencies: ["KadiEngine"]
        ),
    ]
)
