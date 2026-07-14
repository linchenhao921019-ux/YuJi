// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "YuJi",
    platforms: [.macOS(.v15)],
    products: [
        .executable(name: "YuJi", targets: ["YuJi"])
    ],
    targets: [
        .executableTarget(
            name: "YuJi",
            path: "Sources/YuJi",
            swiftSettings: [
                .unsafeFlags(["-Xfrontend", "-strict-concurrency=minimal"])
            ]
        )
    ]
)
