import Foundation

struct HTTPRequest: Sendable {
    let method: String
    let path: String
    let headers: [String: String]

    static func parse(_ data: Data) -> HTTPRequest? {
        guard let string = String(data: data, encoding: .utf8),
              let headerPart = string.components(separatedBy: "\r\n\r\n").first else { return nil }
        let lines = headerPart.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else { return nil }
        let parts = requestLine.split(separator: " ")
        guard parts.count >= 2 else { return nil }

        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            guard let separator = line.firstIndex(of: ":") else { continue }
            let key = line[..<separator].trimmingCharacters(in: .whitespaces).lowercased()
            let value = line[line.index(after: separator)...].trimmingCharacters(in: .whitespaces)
            headers[key] = value
        }
        return HTTPRequest(method: String(parts[0]), path: String(parts[1]), headers: headers)
    }
}

struct HTTPResponse: Sendable {
    let status: Int
    let body: Data
    let contentType: String

    init(status: Int = 200, body: Data, contentType: String = "application/json; charset=utf-8") {
        self.status = status
        self.body = body
        self.contentType = contentType
    }

    func serialized() -> Data {
        let reason: String = switch status {
        case 200: "OK"
        case 400: "Bad Request"
        case 401: "Unauthorized"
        case 404: "Not Found"
        case 405: "Method Not Allowed"
        default: "Internal Server Error"
        }
        let header = "HTTP/1.1 \(status) \(reason)\r\nContent-Type: \(contentType)\r\nContent-Length: \(body.count)\r\nConnection: close\r\n\r\n"
        var data = Data(header.utf8)
        data.append(body)
        return data
    }
}
