// swift-tools-version: 5.8

import PackageDescription

let package = Package(
    name: "language",
    products: [
        .library(name: "LanguageFrontendInternals", targets: ["LanguageFrontendInternals"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", .upToNextMajor(from: "1.2.0"))
    ],
    targets: [
        .target(
            name: "LanguageFrontendInternals",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ],
            path: "Sources/FrontendInternals"
        ),
        .executableTarget(
            name: "LanguageFrontendCLI",
            dependencies: [
                .target(name: "LanguageFrontendInternals")
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
