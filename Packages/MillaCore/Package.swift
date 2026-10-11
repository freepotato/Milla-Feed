// swift-tools-version: 6.0
//
//  MillaCore —— 与平台无关的纯 Swift 核心库。
//  仅依赖 Foundation（可在 macOS / Linux / Windows 的 OSS Swift 工具链编译）。
//

import PackageDescription

let package = Package(
    name: "MillaCore",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .library(name: "MillaCore", targets: ["MillaCore"]),
        .executable(name: "milla-cli", targets: ["milla-cli"])
    ],
    targets: [
        .target(
            name: "MillaCore",
            path: "Sources/MillaCore"
        ),
        .executableTarget(
            name: "milla-cli",
            dependencies: ["MillaCore"],
            path: "Sources/milla-cli"
        ),
        .testTarget(
            name: "MillaCoreTests",
            dependencies: ["MillaCore"],
            path: "Tests/MillaCoreTests"
        )
    ],
    swiftLanguageModes: [.v5]
)
