import Foundation
import UIBridgeMacCore
import UIBridgeProtocol

enum LocalBridgeClientError: LocalizedError {
    case invalidArguments(String)
    case server(Int, String)

    var errorDescription: String? {
        switch self {
        case .invalidArguments(let message): message
        case .server(let status, let body): "bridge returned HTTP \(status): \(body)"
        }
    }
}

struct LocalBridgeClient {
    let token: String
    let baseURL: URL

    init(token: String, port: UInt16 = 8765) {
        self.token = token
        self.baseURL = URL(string: "http://127.0.0.1:\(port)")!
    }

    func call(tool: String, argumentsJSON: String?) async throws -> Data {
        let arguments = try parseArguments(argumentsJSON)
        switch tool {
        case "permissions_get":
            return try await request(method: "GET", path: "/v1/permissions")
        case "diagnostics_get":
            return try await request(method: "GET", path: "/v1/diagnostics")
        case "apps_list":
            return try await request(method: "GET", path: "/v1/apps")
        case "windows_list":
            guard let pid = integer(arguments["pid"]) else {
                throw LocalBridgeClientError.invalidArguments("windows_list requires integer pid")
            }
            return try await request(method: "GET", path: "/v1/apps/\(pid)/windows")
        case "snapshot_get":
            return try await request(method: "POST", path: "/v1/snapshots", body: try snapshotBody(arguments))
        case "element_find":
            guard let snapshotID = arguments["snapshot_id"] as? String else {
                throw LocalBridgeClientError.invalidArguments("element_find requires snapshot_id")
            }
            return try await request(method: "POST", path: "/v1/elements/find", body: try JSONEncoder().encode(
                ElementFindEnvelope(
                    snapshotID: snapshotID,
                    role: arguments["role"] as? String,
                    text: arguments["text"] as? String,
                    enabled: arguments["enabled"] as? Bool,
                    settable: arguments["settable"] as? Bool,
                    limit: integer(arguments["limit"])
                )
            ))
        case "plan_check":
            return try await request(method: "POST", path: "/v1/plans/check", body: try planBody(arguments))
        case "action_run":
            return try await request(method: "POST", path: "/v1/actions", body: try actionBody(arguments))
        case "emergency_stop":
            return try await request(method: "POST", path: "/v1/emergency-stop", body: Data("{}".utf8))
        default:
            throw LocalBridgeClientError.invalidArguments("unsupported local call tool: \(tool)")
        }
    }

    private func request(method: String, path: String, body: Data? = nil) async throws -> Data {
        var request = URLRequest(url: baseURL.appendingPathComponent(String(path.dropFirst())))
        request.httpMethod = method
        request.httpBody = body
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(String(body.count), forHTTPHeaderField: "Content-Length")
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            throw LocalBridgeClientError.server(status, String(decoding: data, as: UTF8.self))
        }
        return data
    }

    private func parseArguments(_ json: String?) throws -> [String: Any] {
        guard let json, !json.isEmpty else { return [:] }
        guard let value = try JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any] else {
            throw LocalBridgeClientError.invalidArguments("arguments must be one JSON object")
        }
        return value
    }

    private func snapshotBody(_ arguments: [String: Any]) throws -> Data {
        guard let pid = integer(arguments["pid"]), let windowID = integer(arguments["window_id"]),
              let pid32 = Int32(exactly: pid), let windowID32 = UInt32(exactly: windowID) else {
            throw LocalBridgeClientError.invalidArguments("snapshot_get requires valid pid and window_id")
        }
        return try JSONEncoder().encode(SnapshotEnvelope(
            pid: pid32,
            windowID: windowID32,
            includeScreenshot: arguments["include_screenshot"] as? Bool,
            maxElements: integer(arguments["max_elements"]),
            maxDepth: integer(arguments["max_depth"])
        ))
    }

    private func planBody(_ arguments: [String: Any]) throws -> Data {
        guard let snapshotID = arguments["snapshot_id"] as? String,
              let actionRaw = arguments["action"] as? String,
              let action = ActionKind(rawValue: actionRaw) else {
            throw LocalBridgeClientError.invalidArguments("plan_check requires snapshot_id and action")
        }
        let coordinate: UIBPoint? = if let x = number(arguments["coordinate_x"]),
                                       let y = number(arguments["coordinate_y"]) {
            UIBPoint(x: x, y: y)
        } else { nil }
        return try JSONEncoder().encode(PlanEnvelope(
            snapshotID: snapshotID,
            elementHandle: arguments["element_handle"] as? String,
            action: action,
            coordinate: coordinate,
            delivery: (arguments["delivery"] as? String).flatMap(DeliveryPreference.init(rawValue:)),
            highImpact: arguments["high_impact"] as? Bool,
            confirmed: arguments["confirmed"] as? Bool,
            foregroundApproved: arguments["foreground_approved"] as? Bool
        ))
    }

    private func actionBody(_ arguments: [String: Any]) throws -> Data {
        guard let snapshotID = arguments["snapshot_id"] as? String,
              let actionRaw = arguments["action"] as? String,
              let action = ActionKind(rawValue: actionRaw),
              let verificationRaw = arguments["verification_kind"] as? String,
              let verification = VerificationExpectation.Kind(rawValue: verificationRaw) else {
            throw LocalBridgeClientError.invalidArguments("action_run requires snapshot_id, action, and verification_kind")
        }
        let target: ActionTarget
        if action == .coordinateClick,
           let x = number(arguments["coordinate_x"]), let y = number(arguments["coordinate_y"]) {
            target = .coordinate(point: UIBPoint(x: x, y: y))
        } else if let handle = arguments["element_handle"] as? String {
            target = .element(handle: handle)
        } else {
            throw LocalBridgeClientError.invalidArguments("action_run requires element_handle or coordinate target")
        }
        let request = ActionRequest(
            snapshotID: snapshotID,
            target: target,
            action: action,
            delivery: (arguments["delivery"] as? String).flatMap(DeliveryPreference.init(rawValue:)) ?? .background,
            text: arguments["text"] as? String,
            key: arguments["key"] as? String,
            verification: VerificationExpectation(kind: verification, value: arguments["verification_value"] as? String)
        )
        return try JSONEncoder().encode(ActionEnvelope(
            request: request,
            highImpact: arguments["high_impact"] as? Bool,
            confirmed: arguments["confirmed"] as? Bool,
            foregroundApproved: arguments["foreground_approved"] as? Bool,
            riskCategory: (arguments["risk_category"] as? String).flatMap(DangerousActionCategory.init(rawValue:)),
            confirmationSummary: arguments["confirmation_summary"] as? String
        ))
    }

    private func integer(_ value: Any?) -> Int? {
        (value as? NSNumber)?.intValue
    }

    private func number(_ value: Any?) -> Double? {
        (value as? NSNumber)?.doubleValue
    }
}

private struct ActionEnvelope: Encodable {
    let request: ActionRequest
    let highImpact: Bool?
    let confirmed: Bool?
    let foregroundApproved: Bool?
    let riskCategory: DangerousActionCategory?
    let confirmationSummary: String?
}

private struct SnapshotEnvelope: Encodable {
    let pid: Int32
    let windowID: UInt32
    let includeScreenshot: Bool?
    let maxElements: Int?
    let maxDepth: Int?
}

private struct ElementFindEnvelope: Encodable {
    let snapshotID: String
    let role: String?
    let text: String?
    let enabled: Bool?
    let settable: Bool?
    let limit: Int?
}

private struct PlanEnvelope: Encodable {
    let snapshotID: String
    let elementHandle: String?
    let action: ActionKind
    let coordinate: UIBPoint?
    let delivery: DeliveryPreference?
    let highImpact: Bool?
    let confirmed: Bool?
    let foregroundApproved: Bool?
}
