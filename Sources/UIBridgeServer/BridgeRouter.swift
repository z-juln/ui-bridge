import Foundation
import UIBridgeMacCore
import UIBridgeProtocol

struct BridgeRouter: Sendable {
    let token: String
    let runtime: AutomationRuntime
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(token: String, runtime: AutomationRuntime = AutomationRuntime()) {
        self.token = token
        self.runtime = runtime
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
    }

    func route(_ request: HTTPRequest) async -> HTTPResponse {
        if request.path == "/health" {
            guard request.method == "GET" else { return json(status: 405, ["error": "method_not_allowed"]) }
            return json(["status": "ok", "service": "macos-ui-bridge"])
        }
        guard request.headers["authorization"] == "Bearer \(token)" else {
            return json(status: 401, ["error": "unauthorized"])
        }

        switch (request.method, request.path) {
        case ("GET", "/v1/apps"):
            return encode(AppDiscovery.listRunningApplications())
        case ("GET", "/v1/permissions"):
            return encode(PermissionInspector.current())
        case ("POST", "/v1/snapshots"):
            do {
                let input = try decoder.decode(SnapshotInput.self, from: request.body)
                return encode(try await runtime.createSnapshot(
                    pid: input.pid,
                    windowID: input.windowID,
                    includeScreenshot: input.includeScreenshot ?? false,
                    maxElements: input.maxElements ?? 1_000,
                    maxDepth: input.maxDepth ?? 20
                ))
            } catch { return bridgeFailure(error) }
        case ("POST", "/v1/actions"):
            do {
                let input = try decoder.decode(ActionInput.self, from: request.body)
                return encode(try await runtime.execute(
                    input.request,
                    highImpact: input.highImpact ?? false,
                    confirmed: input.confirmed ?? false
                ))
            } catch { return bridgeFailure(error) }
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
}
