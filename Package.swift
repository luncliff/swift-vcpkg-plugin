// swift-tools-version: 6.0
import PackageDescription

let name = "swift-vcpkg-plugin"

let products: [Product] = [
    .plugin(
        name: name,
        targets: [name]
    )
]

let dependencies: [Package.Dependency] = [
    // .package(url: "...", branch: "...")
]

/// @see https://github.com/swiftlang/swift-package-manager/blob/main/Documentation/Plugins.md
let targets: [Target] = [
    .plugin(
        name: name,
        capability: .buildTool()
    ),
    .testTarget(
        name: "\(name)Tests",
        path: "Tests",
        swiftSettings: [
            .interoperabilityMode(.Cxx)
        ],
        linkerSettings: [
            .linkedFramework("Foundation"),
            .linkedFramework("XCTest")
        ]
    )
]

let package = Package(
    name: name,
    // platforms: [.macOS(.v11)],
    products: products,
    targets: targets,
    swiftLanguageModes: [SwiftLanguageMode.v6]
)
