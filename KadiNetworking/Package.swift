// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "KadiNetworking",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "KadiNetworking",
            targets: ["KadiNetworking"]
        ),
    ],
    dependencies: [
        .package(path: "../KadiEngine"),
    ],
    targets: [
        .target(
            name: "KadiNetworking",
            dependencies: ["KadiEngine"]
        ),
        .testTarget(
            name: "KadiNetworkingTests",
            dependencies: ["KadiNetworking"]
        ),
    ]
)
