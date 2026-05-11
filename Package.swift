// swift-tools-version: 5.9
import PackageDescription

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
    targets: [
        .executableTarget(
            name: "HomebewMenubar",
            path: "Sources/HomebewMenubar"
        )
    ]
)
