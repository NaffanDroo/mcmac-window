// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "McMacWindow",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "McMacWindow", targets: ["McMacWindow"]),
        .library(name: "McMacWindowCore", targets: ["McMacWindowCore"]),
    ],
    targets: [
        .target(
            name: "McMacWindowCore",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("ApplicationServices"),
                .linkedFramework("Carbon"),
                .linkedFramework("IOKit"),
            ]
        ),
        .executableTarget(
            name: "McMacWindow",
            dependencies: ["McMacWindowCore"]
        ),
        .testTarget(
            name: "McMacWindowTests",
            dependencies: ["McMacWindowCore"]
        ),
    ]
)
