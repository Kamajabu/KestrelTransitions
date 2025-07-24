// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "KestrelTransition",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(
            name: "KestrelTransition",
            targets: ["KestrelTransition"]
        )
    ],
    targets: [
        .target(
            name: "KestrelTransition",
            path: "Sources/KestrelTransition"
        ),
        .testTarget(
            name: "KestrelTransitionTests",
            dependencies: ["KestrelTransition"],
            path: "Tests/KestrelTransitionTests"
        )
    ]
)