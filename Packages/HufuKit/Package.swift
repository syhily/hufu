// swift-tools-version: 6.2
import PackageDescription

let strictSwift: [SwiftSetting] = [
    .enableUpcomingFeature("ExistentialAny"),
    .enableUpcomingFeature("InternalImportsByDefault"),
]

let package = Package(
    name: "HufuKit",
    defaultLocalization: "zh-Hans",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "RimeKit", targets: ["RimeKit"]),
        .library(name: "HufuCore", targets: ["HufuCore"]),
        .library(name: "HufuPanel", targets: ["HufuPanel"]),
        .library(name: "HufuAI", targets: ["HufuAI"]),
        .executable(name: "hufu", targets: ["hufu"]),
    ],
    dependencies: [
        .package(url: "https://github.com/jpsim/Yams.git", from: "6.0.0"),
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.6.0"),
    ],
    targets: [
        // librime 1.17, statically linked from source built by scripts/build-librime.sh.
        .binaryTarget(name: "CRime", path: "Frameworks/CRime.xcframework"),

        // Thin, typed Swift wrapper over the librime C API.
        .target(
            name: "RimeKit",
            dependencies: ["CRime"],
            swiftSettings: strictSwift,
            linkerSettings: [.linkedLibrary("c++")]
        ),

        // Configuration model, patch writer, importer, dictionary packages.
        .target(
            name: "HufuCore",
            dependencies: [.product(name: "Yams", package: "Yams")],
            resources: [.copy("Resources/catalog.json")],
            swiftSettings: strictSwift
        ),

        // AppKit candidate panel shared by the input method and the settings preview.
        .target(name: "HufuPanel", dependencies: ["HufuCore"], swiftSettings: strictSwift),

        // Optional AI assistant. Never touches composition buffers or user dictionaries.
        .target(name: "HufuAI", dependencies: ["HufuCore"], swiftSettings: strictSwift),

        .executableTarget(
            name: "hufu",
            dependencies: [
                "RimeKit", "HufuCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            swiftSettings: strictSwift
        ),

        .testTarget(name: "RimeKitTests", dependencies: ["RimeKit"]),
        .testTarget(name: "HufuCoreTests", dependencies: ["HufuCore", "RimeKit"], exclude: ["Fixtures"]),
        .testTarget(name: "HufuPanelTests", dependencies: ["HufuPanel"]),
        .testTarget(name: "HufuAITests", dependencies: ["HufuAI"]),
    ]
)
