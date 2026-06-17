// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "MacEnvManager",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "MacEnvCore", targets: ["MacEnvCore"]),
        .executable(name: "MacEnvManager", targets: ["MacEnvManager"])
    ],
    targets: [
        .target(name: "MacEnvCore"),
        .executableTarget(
            name: "MacEnvManager",
            dependencies: ["MacEnvCore"]
        ),
        .testTarget(
            name: "MacEnvCoreTests",
            dependencies: ["MacEnvCore"]
        )
    ]
)
