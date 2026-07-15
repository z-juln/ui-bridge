@preconcurrency import Network
import Foundation
import UIBridgeMacCore

public final class HTTPServer: @unchecked Sendable {
    public let port: UInt16
    private let router: BridgeRouter
    private let queue = DispatchQueue(label: "com.juln.ui-bridge.http")
    private var listener: NWListener?

    private init(port: UInt16 = 8765, token: String, runtime: AutomationRuntime, mcpHTTP: MCPHTTPHandler?) {
        self.port = port
        self.router = BridgeRouter(token: token, runtime: runtime, mcpHTTP: mcpHTTP)
    }

    public static func make(port: UInt16 = 8765, token: String) async throws -> HTTPServer {
        let runtime = AutomationRuntime(activitySource: "本地地址 MCP")
        let mcpHTTP = try await MCPHTTPHandler.make(runtime: runtime)
        return HTTPServer(port: port, token: token, runtime: runtime, mcpHTTP: mcpHTTP)
    }

    public func start() throws {
        guard listener == nil else { return }
        guard let nwPort = NWEndpoint.Port(rawValue: port) else {
            throw NSError(domain: "UIBridgeServer", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid port \(port)"])
        }
        let parameters = NWParameters.tcp
        parameters.allowLocalEndpointReuse = true
        parameters.requiredInterfaceType = .loopback
        let listener = try NWListener(using: parameters, on: nwPort)
        listener.newConnectionHandler = { [weak self] connection in self?.accept(connection) }
        listener.stateUpdateHandler = { state in
            if case let .failed(error) = state { fputs("HTTP listener failed: \(error)\n", stderr) }
        }
        self.listener = listener
        listener.start(queue: queue)
    }

    public func stop() {
        listener?.cancel()
        listener = nil
    }

    private func accept(_ connection: NWConnection) {
        connection.start(queue: queue)
        receiveRequest(on: connection, buffer: Data())
    }

    private func receiveRequest(on connection: NWConnection, buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 1_048_576) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            var received = buffer
            if let data { received.append(data) }
            if received.count > 1_048_576 {
                self.sendBadRequest(on: connection)
                return
            }
            if let expectedLength = HTTPRequest.expectedLength(received), received.count >= expectedLength {
                let requestData = Data(received.prefix(expectedLength))
                Task {
                    let response: HTTPResponse
                    if let request = HTTPRequest.parse(requestData) {
                        response = await self.router.route(request)
                    } else {
                        response = HTTPResponse(status: 400, body: Data("{\"error\":\"bad_request\"}".utf8))
                    }
                    connection.send(content: response.serialized(), completion: .contentProcessed { _ in connection.cancel() })
                }
                return
            }
            if error != nil || isComplete {
                self.sendBadRequest(on: connection)
            } else {
                self.receiveRequest(on: connection, buffer: received)
            }
        }
    }

    private func sendBadRequest(on connection: NWConnection) {
        let response = HTTPResponse(status: 400, body: Data("{\"error\":\"bad_request\"}".utf8))
        connection.send(content: response.serialized(), completion: .contentProcessed { _ in connection.cancel() })
    }
}
