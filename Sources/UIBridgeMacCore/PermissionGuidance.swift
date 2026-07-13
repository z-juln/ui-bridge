import AppKit
import ApplicationServices
import CoreGraphics
import Foundation

@MainActor
public enum PermissionGuidance {
    private static var presentedKinds = Set<String>()

    public static func presentIfNeeded(for _: PermissionStatus) {
        requestMissingPermissions(for: PermissionInspector.current())

        let currentStatus = PermissionInspector.current()
        let missing = missingKinds(for: currentStatus)
        guard !missing.isEmpty else { return }

        let key = missing.joined(separator: ",")
        guard presentedKinds.insert(key).inserted else { return }

        NSApplication.shared.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "macOS UI Bridge 需要系统权限"
        alert.informativeText = "缺少\(missing.joined(separator: "、"))权限。授权后才能可靠读取和操作应用界面。"
        alert.addButton(withTitle: "前往设置")
        alert.addButton(withTitle: "稍后")

        if alert.runModal() == .alertFirstButtonReturn,
           let url = settingsURL(for: missing[0]) {
            NSWorkspace.shared.open(url)
        }
    }

    public static func missingKinds(for status: PermissionStatus) -> [String] {
        var result: [String] = []
        if !status.accessibilityTrusted { result.append("辅助功能") }
        if status.screenCaptureAllowed == false { result.append("屏幕录制") }
        return result
    }

    private static func settingsURL(for kind: String) -> URL? {
        let pane = kind == "辅助功能" ? "Privacy_Accessibility" : "Privacy_ScreenCapture"
        return URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)")
    }

    private static func requestMissingPermissions(for status: PermissionStatus) {
        // Screen capture presents a blocking system prompt; request it first so
        // the non-blocking Accessibility prompt cannot overlap or hide it.
        if status.screenCaptureAllowed == false {
            _ = CGRequestScreenCaptureAccess()
        }
        if !status.accessibilityTrusted {
            let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
            _ = AXIsProcessTrustedWithOptions(options)
        }
    }
}
