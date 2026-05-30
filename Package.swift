// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "MacACGuard",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "MacACGuard", targets: ["MacACGuard"])
    ],
    targets: [
        .executableTarget(
            name: "MacACGuard",
            path: "MacACGuard",
            resources: [
                .process("Resources")
            ],
            linkerSettings: [
                .linkedFramework("IOKit")
            ]
        ),
        .testTarget(
            name: "MacACGuardTests",
            dependencies: ["MacACGuard"],
            path: "Tests"
        )
    ]
)
