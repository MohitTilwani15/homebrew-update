// swift-tools-version: 5.9
import Foundation
import PackageDescription

let enableSparkle = ProcessInfo.processInfo.environment["ENABLE_SPARKLE"] == "1"

let package = Package(
    name: "HomebewMenubar",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "HomebewMenubar",
            targets: ["HomebewMenubar"]
        )
    ],
    dependencies: enableSparkle ? [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.9.1")
    ] : [],
    targets: [
        .executableTarget(
            name: "HomebewMenubar",
            dependencies: enableSparkle ? [
                .product(name: "Sparkle", package: "Sparkle")
            ] : [],
            path: "Sources/HomebewMenubar",
            swiftSettings: enableSparkle ? [
                .define("ENABLE_SPARKLE")
            ] : []
        )
    ]
)
