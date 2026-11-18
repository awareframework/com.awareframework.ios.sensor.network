// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "com.awareframework.ios.sensor.network",
    platforms: [.iOS(.v13), .macOS(.v10_15)],
    products: [
        .library(
            name: "com.awareframework.ios.sensor.network",
            targets: [
                "com.awareframework.ios.sensor.network"
            ]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/awareframework/com.awareframework.ios.core.git", from: "1.6.3")
    ],
    targets: [
        .target(
            name: "com.awareframework.ios.sensor.network",
            dependencies: [
                .product(name: "com.awareframework.ios.core", package: "com.awareframework.ios.core")
            ],
            path: "Sources/com.awareframework.ios.sensor.network"
        ),
        .testTarget(
            name: "com.awareframework.ios.sensor.networkTests",
            dependencies: ["com.awareframework.ios.core", "com.awareframework.ios.sensor.network"]
        )
    ],
    swiftLanguageModes: [.v5]
)
