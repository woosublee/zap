// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "Snap",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "Snap", targets: ["SnapApp"]),
        .library(name: "SnapCore", targets: ["SnapCore"])
    ],
    targets: [
        .target(
            name: "SnapCore",
            path: "Sources/SnapCore"
        ),
        .executableTarget(
            name: "SnapApp",
            dependencies: ["SnapCore"],
            path: "Sources/SnapApp",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("Carbon"),
                .linkedFramework("ServiceManagement")
            ]
        ),
        .testTarget(
            name: "SnapCoreTests",
            dependencies: ["SnapCore"],
            path: "Tests/SnapCoreTests"
        ),
        .testTarget(
            name: "SnapAppTests",
            dependencies: ["SnapApp"],
            path: "Tests/SnapAppTests"
        )
    ]
)
