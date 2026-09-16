// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "UTUVOPaw",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "UTUVOPaw",
            path: "Sources/UTUVOPaw",
            resources: [.copy("Assets")],
            swiftSettings: [.swiftLanguageMode(.v5)],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI"),
                .linkedFramework("UniformTypeIdentifiers"),
            ]
        ),
        .testTarget(
            name: "UTUVOPawTests",
            dependencies: ["UTUVOPaw"],
            path: "Tests/UTUVOPawTests",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
