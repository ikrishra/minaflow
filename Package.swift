// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MinaType",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "MinaType", targets: ["MinaType"])
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.6.0")
    ],
    targets: [
        .executableTarget(
            name: "MinaType",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle")
            ],
            path: "Sources/MinaType"
        )
    ]
)
