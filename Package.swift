// swift-tools-version: 5.8

import PackageDescription

let package = Package(
    name: "language",
    products: [
        .library(name: "LanguageFrontendInternals", targets: ["LanguageFrontendInternals"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", .upToNextMajor(from: "1.2.0")),
        .package(url: "https://github.com/apple/swift-algorithms", .upToNextMajor(from: "1.0.0")),
        .package(url: "https://github.com/apple/swift-collections", .upToNextMajor(from: "1.0.0"))
    ],
    targets: [
        .target(
            name: "LanguageFrontendInternals",
            dependencies: [
                .product(name: "Algorithms", package: "swift-algorithms"),
                .product(name: "DequeModule", package: "swift-collections")
            ],
            path: "Sources/FrontendInternals"
        ),
        .executableTarget(
            name: "LanguageFrontendCLI",
            dependencies: [
                .target(name: "LanguageFrontendInternals"),
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ],
            path: "Sources/FrontendCLI"
        ),
        .testTarget(
            name: "LanguageTests",
            dependencies: [
                .target(name: "LanguageFrontendInternals")
            ],
            path: "Tests"
        )
    ]
)
