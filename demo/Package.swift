// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "demo",
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: "https://github.com/danelikethedog/azure-sdk-for-c-swift", from: "1.0.0"),
        .package(path: "../"),
        .package(url: "https://github.com/matsune/swift-mqtt", from: "1.0.0")
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .executableTarget(
            name: "demo",
            dependencies: [
                .product(name: "AzureSDKForCSwift", package: "azure-sdk-for-c-swift"),
                .product(name: "MQTT", package: "swift-mqtt")
                ]),
        .testTarget(
            name: "demoTests",
            dependencies: ["demo"]),
    ]
)
