// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CellarCore",
    platforms: [
        .macOS(.v15),
        .iOS(.v18)
    ],
    products: [
        .library(name: "CellarCore", targets: ["CellarCore"]),
        .library(name: "CellarHost", targets: ["CellarHost"]),
        .library(name: "CellarUI", targets: ["CellarUI"]),
        .executable(name: "CellarPreviewApp", targets: ["CellarPreviewApp"])
    ],
    targets: [
        .target(
            name: "CellarCore"
        ),
        .target(
            name: "CellarHost",
            dependencies: ["CellarCore"]
        ),
        .target(
            name: "CellarUI",
            dependencies: ["CellarHost", "CellarCore"]
        ),
        .executableTarget(
            name: "CellarPreviewApp",
            dependencies: ["CellarUI"]
        ),
        .testTarget(
            name: "CellarCoreTests",
            dependencies: ["CellarCore"]
        ),
        .testTarget(
            name: "CellarHostTests",
            dependencies: ["CellarHost", "CellarCore"]
        ),
        .testTarget(
            name: "CellarUITests",
            dependencies: ["CellarUI", "CellarHost", "CellarCore"]
        )
    ]
)
