// swift-tools-version: 5.8

import PackageDescription

let package = Package(
    name: "language",
    products: [
        .library(name: "LanguageFrontendInternals", targets: ["LanguageFrontendInternals"])
    ],
    targets: [
        .target(
            name: "LanguageFrontendInternals",
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
