// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "ui-bridge",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "UIBridgeProtocol", targets: ["UIBridgeProtocol"]),
        .library(name: "UIBridgeMacCore", targets: ["UIBridgeMacCore"]),
        .library(name: "UIBridgeServer", targets: ["UIBridgeServer"]),
        .library(name: "UIBridgeMCP", targets: ["UIBridgeMCP"]),
        .executable(name: "ui-bridge", targets: ["ui-bridge"]),
    ],
    dependencies: [
        .package(url: "https://github.com/modelcontextprotocol/swift-sdk.git", from: "0.12.1"),
    ],
    targets: [
        .target(name: "UIBridgeProtocol"),
        .target(
            name: "UIBridgeMacCore",
            dependencies: ["UIBridgeProtocol"]
        ),
        .target(
            name: "UIBridgeServer",
            dependencies: [
                "UIBridgeProtocol",
                "UIBridgeMacCore",
                "UIBridgeMCP",
                .product(name: "MCP", package: "swift-sdk"),
            ]
        ),
        .target(
            name: "UIBridgeMCP",
            dependencies: [
                "UIBridgeProtocol",
                "UIBridgeMacCore",
                .product(name: "MCP", package: "swift-sdk"),
            ]
        ),
        .executableTarget(
            name: "ui-bridge",
            dependencies: ["UIBridgeProtocol", "UIBridgeMacCore", "UIBridgeServer", "UIBridgeMCP"],
            swiftSettings: [.unsafeFlags(["-parse-as-library"])]
        ),
        .executableTarget(
            name: "protocol-self-test",
            dependencies: ["UIBridgeProtocol"]
        ),
        .executableTarget(
            name: "core-self-test",
            dependencies: ["UIBridgeMacCore"]
        ),
        .executableTarget(
            name: "safety-self-test",
            dependencies: ["UIBridgeMacCore", "UIBridgeProtocol"]
        ),
        .executableTarget(
            name: "visual-text-self-test",
            dependencies: ["UIBridgeMacCore", "UIBridgeProtocol"]
        ),
        .executableTarget(
            name: "dangerous-action-fixture",
            dependencies: []
        ),
        .executableTarget(
            name: "dangerous-confirmation-fixture",
            dependencies: ["UIBridgeMacCore"]
        ),
    ]
)
