// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "NnArgumentParser",
    platforms: [
        .macOS(.v15),
    ],
    products: [
        .library(
            name: "NnArgumentParser",
            targets: ["NnArgumentParser"]
        ),
        .library(
            name: "NnArgumentParserTesting",
            targets: ["NnArgumentParserTesting"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.7.0")
    ],
    targets: [
        .target(
            name: "NnArgumentParser",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ]
        ),
        .target(
            name: "NnArgumentParserTesting",
            dependencies: [
                "NnArgumentParser"
            ]
        ),
    ]
)
