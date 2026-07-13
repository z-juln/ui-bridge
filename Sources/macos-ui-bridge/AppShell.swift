import AppKit
import Foundation
import UIBridgeMacCore

@MainActor
final class AppShell: NSObject, NSApplicationDelegate {
    private let statusItem: NSStatusItem
    private let token: String

    init(token: String) {
        self.token = token
        NSApplication.shared.setActivationPolicy(.regular)
        let appIcon = Self.makeAppIcon()
        NSApplication.shared.applicationIconImage = appIcon

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()

        let menuBarIcon = Self.makeMenuBarIcon()
        statusItem.button?.image = menuBarIcon
        statusItem.button?.imageScaling = .scaleProportionallyDown
        statusItem.button?.toolTip = "macOS UI Bridge"
        statusItem.menu = makeMenu()
        NSApplication.shared.delegate = self
    }

    func run() {
        NSApplication.shared.run()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        PermissionGuidance.presentIfNeeded(for: PermissionInspector.current())
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu(title: "macOS UI Bridge")
        let status = NSMenuItem(title: "服务运行中 · 127.0.0.1:8765", action: nil, keyEquivalent: "")
        status.isEnabled = false
        menu.addItem(status)
        menu.addItem(.separator())
        menu.addItem(item(title: "检查系统权限", action: #selector(checkPermissions)))
        menu.addItem(item(title: "复制 MCP 连接配置", action: #selector(copyConnection)))
        menu.addItem(.separator())
        menu.addItem(item(title: "退出 macOS UI Bridge", action: #selector(quitApp), key: "q"))
        return menu
    }

    private func item(title: String, action: Selector, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }

    @objc private func checkPermissions() {
        PermissionGuidance.presentIfNeeded(for: PermissionInspector.current(), showSuccess: true)
    }

    @objc private func copyConnection() {
        let config = """
        {"url":"http://127.0.0.1:8765/mcp","headers":{"Authorization":"Bearer \(token)"}}
        """
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(config, forType: .string)
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    private static func makeAppIcon() -> NSImage {
        let size = NSSize(width: 512, height: 512)
        let image = NSImage(size: size)
        image.lockFocus()
        let background = NSBezierPath(roundedRect: NSRect(x: 36, y: 36, width: 440, height: 440), xRadius: 104, yRadius: 104)
        NSColor(calibratedRed: 0.10, green: 0.46, blue: 0.95, alpha: 1).setFill()
        background.fill()

        NSColor.white.setStroke()
        for rect in [NSRect(x: 112, y: 250, width: 180, height: 124), NSRect(x: 220, y: 138, width: 180, height: 124)] {
            let path = NSBezierPath(roundedRect: rect, xRadius: 28, yRadius: 28)
            path.lineWidth = 24
            path.stroke()
        }
        image.unlockFocus()
        image.isTemplate = false
        return image
    }

    private static func makeMenuBarIcon() -> NSImage {
        let canvas = NSSize(width: 38, height: 38)
        let image = NSImage(size: canvas)
        image.lockFocus()
        NSColor.black.setStroke()
        for rect in [NSRect(x: 3, y: 17, width: 19, height: 14), NSRect(x: 16, y: 7, width: 19, height: 14)] {
            let path = NSBezierPath(roundedRect: rect, xRadius: 3.5, yRadius: 3.5)
            path.lineWidth = 3.5
            path.stroke()
        }
        image.unlockFocus()
        image.size = NSSize(width: 19, height: 19)
        image.isTemplate = true
        return image
    }
}
