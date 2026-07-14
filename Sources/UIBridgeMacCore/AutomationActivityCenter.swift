import AppKit
import Foundation
import UIBridgeProtocol

public enum AutomationActivityPhase: String, Sendable {
    case observed
    case confirmationRequested = "confirmation_requested"
    case confirmationRejected = "confirmation_rejected"
    case actionStarted = "action_started"
    case actionFinished = "action_finished"
}

public struct AutomationActivityRecord: Codable, Sendable {
    public let eventID: String
    public let createdAt: Date
    public let phase: AutomationActivityPhase
    public let pid: Int32
    public let appName: String
    public let windowID: UInt32
    public let windowBounds: UIBRect
    public let pointer: UIBPoint?
    public let source: String?
    public let action: String?
    public let risk: String?
}

extension AutomationActivityPhase: Codable {}

public enum AutomationActivityCenter {
    public static let notification = Notification.Name("com.juln.app-mcp-bridge.activity")

    public static func publish(
        phase: AutomationActivityPhase,
        snapshot: Snapshot,
        pointer: UIBPoint? = nil,
        source: String? = nil,
        action: String? = nil,
        risk: String? = nil
    ) {
        let appName = NSRunningApplication(processIdentifier: snapshot.pid)?.localizedName ?? snapshot.appID
        let record = AutomationActivityRecord(
            eventID: UUID().uuidString,
            createdAt: Date(),
            phase: phase,
            pid: snapshot.pid,
            appName: appName,
            windowID: snapshot.windowID,
            windowBounds: snapshot.windowBounds,
            pointer: pointer,
            source: source,
            action: action ?? defaultAction(for: phase),
            risk: risk
        )
        persist(record)
        persistHistory(record)
        var info: [String: Any] = [
            "phase": phase.rawValue,
            "pid": Int(snapshot.pid),
            "app_name": appName,
            "window_x": snapshot.windowBounds.origin.x,
            "window_y": snapshot.windowBounds.origin.y,
            "window_width": snapshot.windowBounds.size.width,
            "window_height": snapshot.windowBounds.size.height,
        ]
        if let pointer {
            info["pointer_x"] = pointer.x
            info["pointer_y"] = pointer.y
        }
        NotificationCenter.default.post(name: notification, object: nil, userInfo: info)
        DistributedNotificationCenter.default().postNotificationName(
            notification,
            object: nil,
            userInfo: info,
            deliverImmediately: true
        )
    }

    private static func defaultAction(for phase: AutomationActivityPhase) -> String {
        switch phase {
        case .observed: "读取界面"
        case .confirmationRequested: "等待确认"
        case .confirmationRejected: "已取消"
        case .actionStarted: "执行操作"
        case .actionFinished: "复查结果"
        }
    }

    public static func latest() -> AutomationActivityRecord? {
        guard let data = try? Data(contentsOf: stateURL) else { return nil }
        return try? JSONDecoder().decode(AutomationActivityRecord.self, from: data)
    }

    public static func recent(since: Date = Date().addingTimeInterval(-90), limit: Int = 100) -> [AutomationActivityRecord] {
        guard let data = try? Data(contentsOf: historyURL),
              let records = try? JSONDecoder().decode([AutomationActivityRecord].self, from: data) else {
            return latest().map { $0.createdAt >= since ? [$0] : [] } ?? []
        }
        return Array(records.filter { $0.createdAt >= since }.suffix(max(1, limit)))
    }

    private static var stateURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/app-mcp-bridge", isDirectory: true)
            .appendingPathComponent("activity.json")
    }

    private static var historyURL: URL {
        stateURL.deletingLastPathComponent().appendingPathComponent("activity-history.json")
    }

    private static func persist(_ record: AutomationActivityRecord) {
        do {
            try FileManager.default.createDirectory(
                at: stateURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try JSONEncoder().encode(record)
            try data.write(to: stateURL, options: [.atomic])
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: stateURL.path)
        } catch {
            // Visible feedback is best-effort and must never fail the desktop action.
        }
    }

    private static func persistHistory(_ record: AutomationActivityRecord) {
        do {
            try FileManager.default.createDirectory(
                at: historyURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let existing = (try? Data(contentsOf: historyURL))
                .flatMap { try? JSONDecoder().decode([AutomationActivityRecord].self, from: $0) } ?? []
            let cutoff = Date().addingTimeInterval(-300)
            let records = Array((existing.filter { $0.createdAt >= cutoff } + [record]).suffix(200))
            try JSONEncoder().encode(records).write(to: historyURL, options: [.atomic])
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: historyURL.path)
        } catch {
            // Debug history is bounded and best-effort; actions must not depend on it.
        }
    }
}
