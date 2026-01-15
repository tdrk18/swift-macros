// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import CompilerPluginSupport
import PackageDescription

let package = Package(
    name: "Macro",
    platforms: [
        .iOS(.v17),
        .macOS(.v10_15),
    ],
    products: [
        .library(
            name: "Macro",
            targets: ["Macro"]
        )
    ],
    dependencies: [
        .package(
            url: "https://github.com/apple/swift-syntax.git",
            from: "602.0.0",
        )
    ],
    targets: [
        .macro(
            name: "MacroImplements",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftSyntaxBuilder", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
            ]
        ),
        .target(
            name: "Macro",
            dependencies: ["MacroImplements"]
        ),
        .testTarget(
            name: "MacroTests",
            dependencies: [
                "Macro",
                "MacroImplements",
                .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
            ]
        ),
    ]
)
