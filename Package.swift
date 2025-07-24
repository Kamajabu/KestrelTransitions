// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "KestrelTransitions",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(
            name: "KestrelTransitions",
            targets: ["KestrelTransitions"]
        )
    ],
    targets: [
        .target(
            name: "KestrelTransitions",
            path: "Sources/KestrelTransition"
        ),
        .testTarget(
            name: "KestrelTransitionTests",
            dependencies: ["KestrelTransitions"],
            path: "Tests/KestrelTransitionTests"
        )
    ]
)