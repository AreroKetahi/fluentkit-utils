// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription
import CompilerPluginSupport

let package = Package(
    name: "fluentkit-utils",
    platforms: [
        .macOS(.v10_15), .iOS(.v13), .tvOS(.v13),
        .watchOS(.v6), .macCatalyst(.v13),
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "FluentKitUtils",
            targets: ["FluentKitUtils"]
        ),
        .executable(
            name: "FluentKitUtilsClient",
            targets: ["FluentKitUtilsClient"]
        ),
    ],
    dependencies: [
        .package(
            url: "https://github.com/swiftlang/swift-syntax.git",
            from: "603.0.0-latest"
        ),
        .package(
            url: "https://github.com/vapor/fluent-kit.git",
            from: "1.55.0"
        ),
        .package(
            url: "https://github.com/pointfreeco/swift-macro-testing.git",
            from: "0.6.5"
        ),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        // Macro implementation that performs the source transformation of a macro.
        .macro(
            name: "FluentKitUtilsMacros",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
                .product(name: "SwiftDiagnostics", package: "swift-syntax"),
            ]
        ),
        
        // Library that exposes a macro as part of its API, which is used in client programs.
        .target(
            name: "FluentKitUtils",
            dependencies: [
                "FluentKitUtilsMacros",
                .product(name: "FluentKit", package: "fluent-kit"),
            ]
        ),
        
        // A client of the library, which is able to use the macro in its own code.
        .executableTarget(
            name: "FluentKitUtilsClient",
            dependencies: ["FluentKitUtils"]
        ),
        
        // A test target used to develop the macro implementation.
        .testTarget(
            name: "FluentKitUtilsTests",
            dependencies: [
                "FluentKitUtils",
                "FluentKitUtilsMacros",
                .product(
                    name: "SwiftSyntaxMacrosTestSupport",
                    package: "swift-syntax"
                ),
                .product(name: "MacroTesting", package: "swift-macro-testing"),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
