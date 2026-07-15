import AppKit
import Foundation

public enum DangerousActionCategory: String, Codable, CaseIterable, Sendable {
    case deletion
    case purchase
    case permissionChange = "permission_change"
    case other

    public var displayName: String {
        switch self {
        case .deletion: "删除"
        case .purchase: "购买"
        case .permissionChange: "权限变更"
        case .other: "高影响操作"
        }
    }
}

public struct DangerousActionConfirmationRequest: Codable, Identifiable, Sendable {
    public let id: String
    public let createdAt: Date
    public let expiresAt: Date
    public let category: DangerousActionCategory
    public let appName: String
    public let action: String
    public let target: String
    public let impact: String
}

public struct DangerousActionConfirmationResponse: Codable, Sendable {
    public let requestID: String
    public let approved: Bool
    public let respondedAt: Date
}

public enum DangerousActionConfirmationCenter {
    public static let defaultTimeout: TimeInterval = 60

    public static var directory: URL {
        if let override = ProcessInfo.processInfo.environment["UI_BRIDGE_CONFIRMATION_DIR"], !override.isEmpty {
            return URL(fileURLWithPath: override, isDirectory: true)
        }
        UIBridgePaths.migrateLegacyDataIfNeeded()
        return UIBridgePaths.applicationSupportDirectory.appendingPathComponent("confirmations", isDirectory: true)
    }

    public static var heartbeatURL: URL { directory.appendingPathComponent("app-heartbeat") }

    public static func requestURL(id: String) -> URL { directory.appendingPathComponent("\(id).request.json") }
    public static func responseURL(id: String) -> URL { directory.appendingPathComponent("\(id).response.json") }

    public static func requestApproval(
        category: DangerousActionCategory,
        appName: String,
        action: String,
        target: String,
        impact: String,
        timeout: TimeInterval = defaultTimeout
    ) async -> Bool {
        guard appIsAvailable else { return false }
        let now = Date()
        let request = DangerousActionConfirmationRequest(
            id: UUID().uuidString,
            createdAt: now,
            expiresAt: now.addingTimeInterval(timeout),
            category: category,
            appName: appName,
            action: action,
            target: target,
            impact: impact
        )
        do {
            try prepareDirectory()
            try JSONEncoder().encode(request).write(to: requestURL(id: request.id), options: .atomic)
            try protect(requestURL(id: request.id))
        } catch {
            return false
        }

        defer {
            try? FileManager.default.removeItem(at: requestURL(id: request.id))
            try? FileManager.default.removeItem(at: responseURL(id: request.id))
        }
        while Date() < request.expiresAt, !Task.isCancelled {
            if let data = try? Data(contentsOf: responseURL(id: request.id)),
               let response = try? JSONDecoder().decode(DangerousActionConfirmationResponse.self, from: data),
               response.requestID == request.id {
                return response.approved
            }
            try? await Task.sleep(for: .milliseconds(150))
        }
        return false
    }

    public static func pendingRequests() -> [DangerousActionConfirmationRequest] {
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        ) else { return [] }
        return urls.filter { $0.lastPathComponent.hasSuffix(".request.json") }.compactMap { url in
            guard let data = try? Data(contentsOf: url),
                  let request = try? JSONDecoder().decode(DangerousActionConfirmationRequest.self, from: data) else {
                try? FileManager.default.removeItem(at: url)
                return nil
            }
            if request.expiresAt <= Date() {
                try? FileManager.default.removeItem(at: url)
                return nil
            }
            return request
        }.sorted { $0.createdAt < $1.createdAt }
    }

    public static func respond(to request: DangerousActionConfirmationRequest, approved: Bool) {
        let response = DangerousActionConfirmationResponse(
            requestID: request.id,
            approved: approved,
            respondedAt: Date()
        )
        do {
            try prepareDirectory()
            try JSONEncoder().encode(response).write(to: responseURL(id: request.id), options: .atomic)
            try protect(responseURL(id: request.id))
        } catch {
            // No response means deny by timeout.
        }
    }

    public static func writeHeartbeat() {
        do {
            try prepareDirectory()
            try Data(String(Date().timeIntervalSince1970).utf8).write(to: heartbeatURL, options: .atomic)
            try protect(heartbeatURL)
        } catch {
            // Callers fail closed when the heartbeat is unavailable.
        }
    }

    private static var appIsAvailable: Bool {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: heartbeatURL.path),
              let modified = attributes[.modificationDate] as? Date else { return false }
        return modified > Date().addingTimeInterval(-2)
    }

    private static func prepareDirectory() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
    }

    private static func protect(_ url: URL) throws {
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }
}
