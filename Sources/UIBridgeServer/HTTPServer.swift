@preconcurrency import Network
import Foundation

public final class HTTPServer: @unchecked Sendable {
    public let port: UInt16
    private let router: BridgeRouter
    private let queue = DispatchQueue(label: "com.juln.macos-ui-bridge.http")
    private var listener: NWListener?

    public init(port: UInt16 = 8765, token: String) {
        self.port = port
        self.router = BridgeRouter(token: token)
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
        connection.receive(minimumIncompleteLength: 1, maximumLength: 1_048_576) { [weak self] data, _, _, error in
            guard let self else { return }
            let response: HTTPResponse
            if let data, let request = HTTPRequest.parse(data) {
                response = self.router.route(request)
            } else {
                response = HTTPResponse(status: 400, body: Data("{\"error\":\"bad_request\"}".utf8))
            }
            connection.send(content: response.serialized(), completion: .contentProcessed { _ in connection.cancel() })
            if error != nil { connection.cancel() }
        }
    }
}
