// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "FynoTOTP",
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "FynoTOTP",
            targets: ["FynoTOTP"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/ccgus/fmdb", from: "2.7.8")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "FynoTOTP",
            dependencies: [
                .product(name: "FMDB", package: "FMDB")
            ]
        )
    ]
)
