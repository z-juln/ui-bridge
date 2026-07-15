import Foundation
import UIBridgeMacCore
import UIBridgeProtocol

struct BridgeRouter: Sendable {
    let token: String
    let runtime: AutomationRuntime
    let mcpHTTP: MCPHTTPHandler?
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(token: String, runtime: AutomationRuntime = AutomationRuntime(), mcpHTTP: MCPHTTPHandler? = nil) {
        self.token = token
        self.runtime = runtime
        self.mcpHTTP = mcpHTTP
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
    }

    func route(_ request: HTTPRequest) async -> HTTPResponse {
        if request.path == "/health" {
            guard request.method == "GET" else { return json(status: 405, ["error": "method_not_allowed"]) }
            return json(["status": "ok", "service": "ui-bridge"])
        }
        guard request.headers["authorization"] == "Bearer \(token)" else {
            return json(status: 401, ["error": "unauthorized"])
        }

        if request.path == "/mcp", let mcpHTTP {
            return await mcpHTTP.handle(request)
        }

        switch (request.method, request.path) {
        case ("GET", "/v1/apps"):
            return encode(AppDiscovery.listRunningApplications())
        case ("GET", "/v1/permissions"):
            return encode(PermissionInspector.current())
        case ("GET", "/v1/diagnostics"):
            let permissions = PermissionInspector.current()
            return encode(HTTPDiagnostics(
                accessibilityReady: permissions.accessibilityTrusted,
                screenCaptureReady: permissions.screenCaptureAllowed == true,
                runningApplicationCount: AppDiscovery.listRunningApplications().count,
                version: "0.1.0"
            ))
        case ("POST", "/v1/snapshots"):
            do {
                let input = try decoder.decode(SnapshotInput.self, from: request.body)
                return encode(try await runtime.createSnapshot(
                    pid: input.pid,
                    windowID: input.windowID,
                    includeScreenshot: input.includeScreenshot ?? false,
                    maxElements: input.maxElements ?? 1_000,
                    maxDepth: input.maxDepth ?? 20,
                    activitySource: request.headers["x-app-mcp-client"] ?? "本地地址 API"
                ))
            } catch { return bridgeFailure(error) }
        case ("POST", "/v1/actions"):
            do {
                let input = try decoder.decode(ActionInput.self, from: request.body)
                return encode(try await runtime.execute(
                    input.request,
                    highImpact: input.highImpact ?? false,
                    confirmed: input.confirmed ?? false,
                    foregroundApproved: input.foregroundApproved ?? false,
                    riskCategory: input.riskCategory ?? .other,
                    confirmationSummary: input.confirmationSummary,
                    activitySource: request.headers["x-app-mcp-client"] ?? "本地地址 API"
                ))
            } catch { return bridgeFailure(error) }
        case ("POST", "/v1/elements/find"):
            do {
                let input = try decoder.decode(ElementFindInput.self, from: request.body)
                return encode(try runtime.findElements(
                    snapshotID: input.snapshotID,
                    role: input.role,
                    text: input.text,
                    enabled: input.enabled,
                    settable: input.settable,
                    limit: input.limit ?? 50
                ))
            } catch { return bridgeFailure(error) }
        case ("POST", "/v1/plans/check"):
            do {
                let input = try decoder.decode(PlanCheckInput.self, from: request.body)
                return encode(try runtime.checkPlan(
                    snapshotID: input.snapshotID,
                    elementHandle: input.elementHandle,
                    action: input.action,
                    coordinate: input.coordinate,
                    delivery: input.delivery ?? .background,
                    highImpact: input.highImpact ?? false,
                    confirmed: input.confirmed ?? false,
                    foregroundApproved: input.foregroundApproved ?? false
                ))
            } catch { return bridgeFailure(error) }
        case ("POST", "/v1/screenshots/get"):
            do {
                let input = try decoder.decode(ScreenshotInput.self, from: request.body)
                guard let data = runtime.screenshotData(handle: input.handle) else {
                    throw BridgeError(code: .snapshotStale, message: "Screenshot handle is expired or unknown.", retryable: true)
                }
                return HTTPResponse(body: data, contentType: "image/png")
            } catch { return bridgeFailure(error) }
        case ("POST", "/v1/emergency-stop"):
            runtime.emergencyStop()
            return json(["status": "stopped", "resume": "restart the service session"])
        default:
            if request.method == "GET", let pid = windowsPID(from: request.path) {
                return encode(WindowDiscovery.listWindows(pid: pid))
            }
            return json(status: request.method == "GET" ? 404 : 405, ["error": request.method == "GET" ? "not_found" : "method_not_allowed"])
        }
    }

    private func windowsPID(from path: String) -> Int32? {
        let components = path.split(separator: "/")
        guard components.count == 4,
              components[0] == "v1",
              components[1] == "apps",
              components[3] == "windows" else { return nil }
        return Int32(components[2])
    }

    private func encode<T: Encodable>(_ value: T) -> HTTPResponse {
        do { return HTTPResponse(body: try encoder.encode(value)) }
        catch { return json(status: 500, ["error": "encoding_failed"]) }
    }

    private func json(status: Int = 200, _ value: [String: String]) -> HTTPResponse {
        HTTPResponse(status: status, body: (try? encoder.encode(value)) ?? Data("{}".utf8))
    }

    private func bridgeFailure(_ error: Error) -> HTTPResponse {
        if let bridge = error as? BridgeError {
            return encodeError(status: bridge.code == .snapshotStale ? 409 : 400, bridge)
        }
        return json(status: 400, ["error": "invalid_request", "message": error.localizedDescription])
    }

    private func encodeError<T: Encodable>(status: Int, _ value: T) -> HTTPResponse {
        HTTPResponse(status: status, body: (try? encoder.encode(value)) ?? Data("{}".utf8))
    }
}

private struct SnapshotInput: Decodable {
    let pid: Int32
    let windowID: UInt32
    let includeScreenshot: Bool?
    let maxElements: Int?
    let maxDepth: Int?
}

private struct ActionInput: Decodable {
    let request: ActionRequest
    let highImpact: Bool?
    let confirmed: Bool?
    let foregroundApproved: Bool?
    let riskCategory: DangerousActionCategory?
    let confirmationSummary: String?
}

private struct ElementFindInput: Decodable {
    let snapshotID: String
    let role: String?
    let text: String?
    let enabled: Bool?
    let settable: Bool?
    let limit: Int?
}

private struct PlanCheckInput: Decodable {
    let snapshotID: String
    let elementHandle: String?
    let action: ActionKind
    let coordinate: UIBPoint?
    let delivery: DeliveryPreference?
    let highImpact: Bool?
    let confirmed: Bool?
    let foregroundApproved: Bool?
}

private struct ScreenshotInput: Decodable {
    let handle: String
}

private struct HTTPDiagnostics: Encodable {
    let accessibilityReady: Bool
    let screenCaptureReady: Bool
    let runningApplicationCount: Int
    let version: String
}
