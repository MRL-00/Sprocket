// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Sprocket",
    platforms: [
        .macOS("26.0")
    ],
    products: [
        .executable(name: "Sprocket", targets: ["Sprocket"]),
        .executable(name: "sprocket", targets: ["SprocketCLI"]),
        .library(name: "SprocketKit", targets: ["SprocketKit"]),
    ],
    targets: [
        .target(
            name: "SprocketKit",
            path: "Sources/SprocketKit"
        ),
        .executableTarget(
            name: "Sprocket",
            dependencies: ["SprocketKit"],
            path: "Sources/SprocketApp"
        ),
        .executableTarget(
            name: "SprocketCLI",
            dependencies: ["SprocketKit"],
            path: "Sources/SprocketCommandLine"
        ),
        .testTarget(
            name: "SprocketKitTests",
            dependencies: ["SprocketKit"],
            path: "Tests/SprocketKitTests"
        ),
    ],
    swiftLanguageModes: [.v6]
)
