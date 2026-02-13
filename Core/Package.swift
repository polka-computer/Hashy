// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "HashyCore",
    platforms: [
        .macOS("14.0"),
        .iOS("17.0"),
    ],
    products: [
        .library(name: "MarkdownStorage", targets: ["MarkdownStorage"]),
        .library(name: "HashyEditor", targets: ["HashyEditor"]),
        .library(name: "AIFeature", targets: ["AIFeature"]),
        .library(name: "AppFeature", targets: ["AppFeature"]),
    ],
    dependencies: [
        .package(
            url: "https://github.com/pointfreeco/swift-composable-architecture.git", from: "1.23.0"),
        .package(url: "https://github.com/pointfreeco/swift-dependencies.git", from: "1.11.0"),
        .package(url: "https://github.com/pointfreeco/swift-sharing.git", from: "2.7.4"),
        .package(url: "https://github.com/krzyzanowskim/STTextView.git", from: "2.3.5"),
        .package(url: "https://github.com/jpsim/Yams.git", from: "6.2.1"),
        .package(
            url: "https://github.com/christopherkarani/Conduit.git", from: "0.3.0",
            traits: ["OpenAI", "OpenRouter"]),
        .package(url: "https://github.com/yaslab/ULID.swift.git", from: "1.3.1"),
    ],
    targets: [
        .target(
            name: "Frontmatter",
            dependencies: [
                .product(name: "Yams", package: "Yams"),
            ],
            path: "Sources/Frontmatter"
        ),
        .target(
            name: "MarkdownStorage",
            dependencies: [
                "Frontmatter",
                .product(name: "ULID", package: "ULID.swift"),
            ],
            path: "Sources/MarkdownStorage",
            resources: [
                .process("Resources")
            ]
        ),
        .target(
            name: "HashyEditor",
            dependencies: [
                .product(name: "STTextView", package: "STTextView")
            ],
            path: "Sources/HashyEditor",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .target(
            name: "AIFeature",
            dependencies: [
                "MarkdownStorage",
                .product(name: "Conduit", package: "Conduit"),
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "DependenciesMacros", package: "swift-dependencies"),
            ],
            path: "Sources/AIFeature"
        ),
        .target(
            name: "AppFeature",
            dependencies: [
                "MarkdownStorage",
                "HashyEditor",
                "AIFeature",
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "DependenciesMacros", package: "swift-dependencies"),
                .product(name: "Sharing", package: "swift-sharing"),
            ],
            path: "Sources/AppFeature",
            resources: [
                .process("Fonts")
            ],
        ),
    ]
)
