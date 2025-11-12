// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "EvmCore",
    platforms: [
        .macOS(.v12),
        .iOS(.v15)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "EvmCore",
            targets: ["EvmCore"]
        ),
        .library(
            name: "Solidity",
            targets: ["Solidity"]
        ),
        .library(
            name: "BIP39",
            targets: ["BIP39"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/attaswift/BigInt.git", from: "5.3.0"),
        .package(url: "https://github.com/krzyzanowskim/CryptoSwift.git", from: "1.8.0"),
        .package(url: "https://github.com/GigaBitcoin/secp256k1.swift.git", from: "0.14.0")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "EvmCore",
            dependencies: [
                "BigInt",
                "CryptoSwift",
                .product(name: "libsecp256k1", package: "secp256k1.swift"),
                "BIP39"
            ]
        ),
        .target(
            name: "Solidity",
            dependencies: []
        ),
        .target(
            name: "BIP39",
            dependencies: [
                "BigInt",
                "CryptoSwift",
                .product(name: "P256K", package: "secp256k1.swift")
            ]
        ),
        .testTarget(
            name: "EvmCoreTests",
            dependencies: ["EvmCore"]
        ),
        .testTarget(
            name: "SolidityTests",
            dependencies: ["Solidity"]
        ),
        .testTarget(
            name: "BIP39Tests",
            dependencies: [
                "BIP39",
                "EvmCore"
            ],
            resources: [
                .process("words.json")
            ]
        ),
    ]
)
