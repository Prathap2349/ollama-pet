// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "OllamaPet",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "OllamaPet",
            targets: ["OllamaPet"]
        )
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "OllamaPet",
            dependencies: [],
            path: "Sources/OllamaPet"
        )
    ]
)
