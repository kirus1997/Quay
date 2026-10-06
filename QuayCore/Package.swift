// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "QuayCore",
    products: [
        .library(name: "QuayCore", targets: ["QuayCore"]),
    ],
    targets: [
        .target(name: "QuayCore"),
        .testTarget(name: "QuayCoreTests", dependencies: ["QuayCore"]),
    ]
)
