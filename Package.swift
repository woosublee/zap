// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "Zap",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "Zap", targets: ["ZapApp"]),
        .library(name: "ZapCore", targets: ["ZapCore"])
    ],
    targets: [
        .target(
            name: "ZapCore",
            path: "Sources/ZapCore"
        ),
        .executableTarget(
            name: "ZapApp",
            dependencies: ["ZapCore"],
            path: "Sources/ZapApp",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("Carbon"),
                .linkedFramework("ServiceManagement")
            ]
        ),
        .testTarget(
            name: "ZapCoreTests",
            dependencies: ["ZapCore"],
            path: "Tests/ZapCoreTests"
        ),
        .testTarget(
            name: "ZapAppTests",
            dependencies: ["ZapApp"],
            path: "Tests/ZapAppTests"
        )
    ]
)
