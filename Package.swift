// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CellarCore",
    platforms: [
        .macOS(.v15),
        .iOS(.v18)
    ],
    products: [
        .library(name: "CellarCore", targets: ["CellarCore"])
    ],
    targets: [
        .target(
            name: "CellarCore"
        ),
        .testTarget(
            name: "CellarCoreTests",
            dependencies: ["CellarCore"]
        )
    ]
)
