// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "Buffer",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Buffer", targets: ["Buffer"]),
    ],
    targets: [
        .target(name: "ClipCore"),
        .executableTarget(name: "Buffer", dependencies: ["ClipCore"]),
        .testTarget(name: "ClipCoreTests", dependencies: ["ClipCore"]),
    ]
)
