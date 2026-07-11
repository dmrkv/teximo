// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "teximo",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .executableTarget(
            name: "teximo",
            path: "Sources/Teximo",
            exclude: ["AppIcon.png", "Info.plist"],
            swiftSettings: [
                .swiftLanguageVersion(.v5)
            ]
        ),
        .testTarget(
            name: "TeximoTests",
            dependencies: ["teximo"]
        ),
    ]
)
