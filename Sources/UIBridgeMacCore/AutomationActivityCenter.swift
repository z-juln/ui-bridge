import AppKit
import Foundation
import UIBridgeProtocol

public enum AutomationActivityPhase: String, Sendable {
    case observed
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
}

extension AutomationActivityPhase: Codable {}

public enum AutomationActivityCenter {
    public static let notification = Notification.Name("com.juln.macos-ui-bridge.activity")

    public static func publish(
        phase: AutomationActivityPhase,
        snapshot: Snapshot,
        pointer: UIBPoint? = nil
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
            pointer: pointer
        )
        persist(record)
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

    public static func latest() -> AutomationActivityRecord? {
        guard let data = try? Data(contentsOf: stateURL) else { return nil }
        return try? JSONDecoder().decode(AutomationActivityRecord.self, from: data)
    }

    private static var stateURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/macos-ui-bridge", isDirectory: true)
            .appendingPathComponent("activity.json")
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
}
