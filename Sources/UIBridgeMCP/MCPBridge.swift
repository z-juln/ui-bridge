import Foundation
import MCP
import UIBridgeMacCore
import UIBridgeProtocol

public enum MCPBridge {
    public static func runStdio() async throws {
        let runtime = AutomationRuntime()
        let server = Server(
            name: "macos-ui-bridge",
            version: "0.1.0",
            instructions: "Inspect and operate macOS applications through live system state.",
            capabilities: .init(tools: .init(listChanged: false))
        )

        await server.withMethodHandler(ListTools.self) { _ in
            .init(tools: [
                Tool(
                    name: "permissions_get",
                    description: "Read the current macOS permissions available to the bridge.",
                    inputSchema: .object(["type": .string("object")])
                ),
                Tool(
                    name: "apps_list",
                    description: "List currently running macOS applications.",
                    inputSchema: .object(["type": .string("object")])
                ),
                Tool(
                    name: "windows_list",
                    description: "List windows owned by one running application process.",
                    inputSchema: .object([
                        "type": .string("object"),
                        "properties": .object([
                            "pid": .object([
                                "type": .string("integer"),
                                "description": .string("Process identifier returned by apps_list"),
                            ])
                        ]),
                        "required": .array([.string("pid")]),
                    ])
                ),
                Tool(
                    name: "snapshot_get",
                    description: "Read the current accessibility tree for one application window.",
                    inputSchema: .object([
                        "type": .string("object"),
                        "properties": .object([
                            "pid": integer("Process identifier returned by apps_list"),
                            "window_id": integer("Window identifier returned by windows_list"),
                            "include_screenshot": boolean("Capture the selected window as well"),
                            "max_elements": integer("Maximum accessibility elements, default 1000"),
                            "max_depth": integer("Maximum accessibility tree depth, default 20"),
                        ]),
                        "required": .array([.string("pid"), .string("window_id")]),
                    ])
                ),
                Tool(
                    name: "action_run",
                    description: "Perform one accessibility action from a live snapshot and verify the resulting UI state.",
                    inputSchema: actionSchema
                ),
            ])
        }

        await server.withMethodHandler(CallTool.self) { params in
            do {
                switch params.name {
                case "permissions_get":
                    let status = PermissionInspector.current()
                    await PermissionGuidance.presentIfNeeded(for: status)
                    return try success(status)
                case "apps_list":
                    return try success(AppDiscovery.listRunningApplications())
                case "windows_list":
                    guard let rawPID = params.arguments?["pid"]?.intValue,
                          let pid = Int32(exactly: rawPID) else {
                        return failure("pid must be a valid 32-bit process identifier")
                    }
                    return try success(WindowDiscovery.listWindows(pid: pid))
                case "snapshot_get":
                    guard let pid = int32(params.arguments?["pid"]),
                          let windowID = uint32(params.arguments?["window_id"]) else {
                        return failure("pid and window_id are required integers")
                    }
                    let snapshot = try await runtime.createSnapshot(
                        pid: pid,
                        windowID: windowID,
                        includeScreenshot: params.arguments?["include_screenshot"]?.boolValue ?? false,
                        maxElements: params.arguments?["max_elements"]?.intValue ?? 1_000,
                        maxDepth: params.arguments?["max_depth"]?.intValue ?? 20
                    )
                    return try success(snapshot)
                case "action_run":
                    guard let request = actionRequest(params.arguments) else {
                        return failure("snapshot_id, action, verification_kind, and a valid element or coordinate target are required")
                    }
                    return try success(try await runtime.execute(
                        request,
                        highImpact: params.arguments?["high_impact"]?.boolValue ?? false,
                        confirmed: params.arguments?["confirmed"]?.boolValue ?? false,
                        foregroundApproved: params.arguments?["foreground_approved"]?.boolValue ?? false
                    ))
                default:
                    return failure("unknown tool: \(params.name)")
                }
            } catch {
                return failure("tool failed: \(error.localizedDescription)")
            }
        }

        let transport = StdioTransport()
        try await server.start(transport: transport)
        await server.waitUntilCompleted()
    }

    private static let actionSchema: Value = .object([
        "type": .string("object"),
        "properties": .object([
            "snapshot_id": string("Current snapshot identifier"),
            "element_handle": string("Element handle from snapshot_get"),
            "action": string("press, select, set_value, type_text, show_menu, press_key, scroll, or coordinate_click"),
            "text": string("Text required by set_value/type_text; signed line count for scroll"),
            "key": string("Key name for press_key: return, tab, space, delete, escape, or an arrow"),
            "coordinate_x": number("Window-relative x coordinate for coordinate_click"),
            "coordinate_y": number("Window-relative y coordinate for coordinate_click"),
            "delivery": string("background by default; foreground returns a consent requirement"),
            "verification_kind": string("element_present, element_absent, element_value_contains, window_title_contains, or screenshot_changed"),
            "verification_value": string("Text expected by the verification"),
            "high_impact": boolean("True for send, publish, delete, purchase, permission change, or submission"),
            "confirmed": boolean("True only after explicit user confirmation for a high-impact action"),
            "foreground_approved": boolean("True only after the user approves bringing the target app forward"),
        ]),
        "required": .array([.string("snapshot_id"), .string("action"), .string("verification_kind")]),
    ])

    private static func actionRequest(_ arguments: [String: Value]?) -> ActionRequest? {
        guard let arguments,
              let snapshotID = arguments["snapshot_id"]?.stringValue,
              let actionValue = arguments["action"]?.stringValue,
              let action = ActionKind(rawValue: actionValue),
              let verificationValue = arguments["verification_kind"]?.stringValue,
              let verificationKind = VerificationExpectation.Kind(rawValue: verificationValue) else { return nil }
        let delivery = arguments["delivery"]?.stringValue.flatMap(DeliveryPreference.init(rawValue:)) ?? .background
        let target: ActionTarget
        if action == .coordinateClick,
           let x = numericValue(arguments["coordinate_x"]),
           let y = numericValue(arguments["coordinate_y"]) {
            target = .coordinate(point: UIBPoint(x: x, y: y))
        } else if let handle = arguments["element_handle"]?.stringValue {
            target = .element(handle: handle)
        } else { return nil }
        return ActionRequest(
            snapshotID: snapshotID,
            target: target,
            action: action,
            delivery: delivery,
            text: arguments["text"]?.stringValue,
            key: arguments["key"]?.stringValue,
            verification: VerificationExpectation(kind: verificationKind, value: arguments["verification_value"]?.stringValue)
        )
    }

    private static func int32(_ value: Value?) -> Int32? {
        value?.intValue.flatMap(Int32.init(exactly:))
    }

    private static func uint32(_ value: Value?) -> UInt32? {
        value?.intValue.flatMap(UInt32.init(exactly:))
    }

    private static func numericValue(_ value: Value?) -> Double? {
        value?.doubleValue ?? value?.intValue.map(Double.init)
    }

    private static func string(_ description: String) -> Value {
        .object(["type": .string("string"), "description": .string(description)])
    }

    private static func integer(_ description: String) -> Value {
        .object(["type": .string("integer"), "description": .string(description)])
    }

    private static func boolean(_ description: String) -> Value {
        .object(["type": .string("boolean"), "description": .string(description)])
    }

    private static func number(_ description: String) -> Value {
        .object(["type": .string("number"), "description": .string(description)])
    }

    private static func success<T: Encodable>(_ value: T) throws -> CallTool.Result {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(value)
        let text = String(decoding: data, as: UTF8.self)
        return .init(content: [.text(text: text, annotations: nil, _meta: nil)], isError: false)
    }

    private static func failure(_ message: String) -> CallTool.Result {
        .init(content: [.text(text: message, annotations: nil, _meta: nil)], isError: true)
    }
}
