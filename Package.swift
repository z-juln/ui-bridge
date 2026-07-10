// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "macos-ui-bridge",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "UIBridgeProtocol", targets: ["UIBridgeProtocol"]),
        .library(name: "UIBridgeMacCore", targets: ["UIBridgeMacCore"]),
        .library(name: "UIBridgeServer", targets: ["UIBridgeServer"]),
        .executable(name: "macos-ui-bridge", targets: ["macos-ui-bridge"]),
    ],
    targets: [
        .target(name: "UIBridgeProtocol"),
        .target(
            name: "UIBridgeMacCore",
            dependencies: ["UIBridgeProtocol"]
        ),
        .target(
            name: "UIBridgeServer",
            dependencies: ["UIBridgeProtocol", "UIBridgeMacCore"]
        ),
        .executableTarget(
            name: "macos-ui-bridge",
            dependencies: ["UIBridgeProtocol", "UIBridgeMacCore", "UIBridgeServer"]
        ),
        .executableTarget(
            name: "protocol-self-test",
            dependencies: ["UIBridgeProtocol"]
        ),
        .executableTarget(
            name: "core-self-test",
            dependencies: ["UIBridgeMacCore"]
        ),
    ]
)
