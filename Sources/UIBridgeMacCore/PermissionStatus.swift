import ApplicationServices
import Foundation

public struct PermissionStatus: Codable, Hashable, Sendable {
    public let accessibilityTrusted: Bool
    public let screenCaptureAllowed: Bool?

    public init(accessibilityTrusted: Bool, screenCaptureAllowed: Bool? = nil) {
        self.accessibilityTrusted = accessibilityTrusted
        self.screenCaptureAllowed = screenCaptureAllowed
    }
}

public enum PermissionInspector {
    public static func current() -> PermissionStatus {
        PermissionStatus(accessibilityTrusted: AXIsProcessTrusted())
    }
}
