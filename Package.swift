// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "swift-logger-tca",
    platforms: [
        .iOS(.v16),
        .tvOS(.v16),
        .macOS(.v13),
        .watchOS(.v9),
        .visionOS(.v1)
    ],
    products: [
        .library(
            name: "LoggerLibraryTCA",
            targets: ["LoggerLibraryTCA"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/swift-loggers/swift-logger.git", branch: "main"),
        .package(url: "https://github.com/pointfreeco/swift-dependencies.git", from: "1.0.0"),
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture.git", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-docc-plugin.git", from: "1.0.0")
    ],
    targets: [
        .target(
            name: "LoggerLibraryTCA",
            dependencies: [
                .product(name: "Loggers", package: "swift-logger"),
                .product(name: "LoggerPrint", package: "swift-logger"),
                .product(name: "LoggerNoOp", package: "swift-logger"),
                .product(name: "Dependencies", package: "swift-dependencies")
            ]
        ),
        .testTarget(
            name: "LoggerLibraryTCATests",
            dependencies: [
                "LoggerLibraryTCA",
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture")
            ]
        )
    ]
)
