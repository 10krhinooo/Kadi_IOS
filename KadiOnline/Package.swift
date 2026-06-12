// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "KadiOnline",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "KadiOnline",
            targets: ["KadiOnline"]
        ),
    ],
    dependencies: [
        .package(path: "../KadiEngine"),
        .package(url: "https://github.com/firebase/firebase-ios-sdk.git", from: "11.0.0"),
        .package(url: "https://github.com/google/GoogleSignIn-iOS.git", from: "8.0.0"),
    ],
    targets: [
        .target(
            name: "KadiOnline",
            dependencies: [
                "KadiEngine",
                .product(name: "FirebaseAuth", package: "firebase-ios-sdk"),
                .product(name: "FirebaseFirestore", package: "firebase-ios-sdk"),
                .product(name: "FirebaseDatabase", package: "firebase-ios-sdk"),
                .product(name: "FirebaseCore", package: "firebase-ios-sdk"),
                .product(name: "GoogleSignIn", package: "GoogleSignIn-iOS"),
                .product(name: "GoogleSignInSwift", package: "GoogleSignIn-iOS"),
            ]
        ),
        .testTarget(
            name: "KadiOnlineTests",
            dependencies: ["KadiOnline"]
        ),
    ]
)
