import Foundation
import UIBridgeMacCore

struct BridgeRouter: Sendable {
    let token: String
    private let encoder: JSONEncoder

    init(token: String) {
        self.token = token
        self.encoder = JSONEncoder()
    }

    func route(_ request: HTTPRequest) -> HTTPResponse {
        guard request.method == "GET" else { return json(status: 405, ["error": "method_not_allowed"]) }
        if request.path == "/health" {
            return json(["status": "ok", "service": "macos-ui-bridge"])
        }
        guard request.headers["authorization"] == "Bearer \(token)" else {
            return json(status: 401, ["error": "unauthorized"])
        }

        switch request.path {
        case "/v1/apps":
            return encode(AppDiscovery.listRunningApplications())
        case "/v1/permissions":
            return encode(PermissionInspector.current())
        default:
            if let pid = windowsPID(from: request.path) {
                return encode(WindowDiscovery.listWindows(pid: pid))
            }
            return json(status: 404, ["error": "not_found"])
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
}
