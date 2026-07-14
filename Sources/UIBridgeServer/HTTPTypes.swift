import Foundation

struct HTTPRequest: Sendable {
    let method: String
    let path: String
    let headers: [String: String]
    let body: Data

    static func expectedLength(_ data: Data) -> Int? {
        guard let separator = data.range(of: Data("\r\n\r\n".utf8)),
              let headerPart = String(data: data[..<separator.lowerBound], encoding: .utf8) else { return nil }
        var contentLength = 0
        for line in headerPart.components(separatedBy: "\r\n").dropFirst() {
            guard let colon = line.firstIndex(of: ":") else { continue }
            let key = line[..<colon].trimmingCharacters(in: .whitespaces)
            if key.caseInsensitiveCompare("Content-Length") == .orderedSame {
                guard let length = Int(line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)), length >= 0 else {
                    return nil
                }
                contentLength = length
            }
        }
        return separator.upperBound + contentLength
    }

    static func parse(_ data: Data) -> HTTPRequest? {
        guard let separator = data.range(of: Data("\r\n\r\n".utf8)),
              let headerPart = String(data: data[..<separator.lowerBound], encoding: .utf8) else { return nil }
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
        return HTTPRequest(
            method: String(parts[0]),
            path: String(parts[1]),
            headers: headers,
            body: Data(data[separator.upperBound...])
        )
    }
}

struct HTTPResponse: Sendable {
    let status: Int
    let body: Data
    let contentType: String
    let additionalHeaders: [String: String]

    init(status: Int = 200, body: Data, contentType: String = "application/json; charset=utf-8", additionalHeaders: [String: String] = [:]) {
        self.status = status
        self.body = body
        self.contentType = contentType
        self.additionalHeaders = additionalHeaders
    }

    func serialized() -> Data {
        let reason: String = switch status {
        case 200: "OK"
        case 202: "Accepted"
        case 400: "Bad Request"
        case 401: "Unauthorized"
        case 409: "Conflict"
        case 404: "Not Found"
        case 405: "Method Not Allowed"
        default: "Internal Server Error"
        }
        let extras = additionalHeaders
            .filter { $0.key.caseInsensitiveCompare("Content-Type") != .orderedSame }
            .map { "\($0.key): \($0.value)\r\n" }
            .joined()
        let header = "HTTP/1.1 \(status) \(reason)\r\nContent-Type: \(contentType)\r\n\(extras)Content-Length: \(body.count)\r\nConnection: close\r\n\r\n"
        var data = Data(header.utf8)
        data.append(body)
        return data
    }
}
