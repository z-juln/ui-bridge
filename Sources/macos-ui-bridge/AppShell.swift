import AppKit
import Foundation
import UIBridgeMacCore

@MainActor
final class AppShell: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let statusItem: NSStatusItem
    private let token: String
    private var overlayController: ControlOverlayController!
    private var statusRefreshTimer: Timer?
    private var statusSignature: String?

    init(token: String) {
        self.token = token
        NSApplication.shared.setActivationPolicy(.regular)
        let appIcon = Self.makeAppIcon()
        NSApplication.shared.applicationIconImage = appIcon

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()
        overlayController = ControlOverlayController()

        updateStatusItem(for: overlayController.activeTargets)
        let menu = makeMenu()
        menu.delegate = self
        statusItem.menu = menu
        overlayController.onTargetsChanged = { [weak self] in
            self?.refreshMenu()
        }
        overlayController.startPolling()
        startStatusRefreshPolling()
        NSApplication.shared.delegate = self
    }

    func run() {
        NSApplication.shared.run()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        PermissionGuidance.presentIfNeeded(for: PermissionInspector.current())
    }

    private func startStatusRefreshPolling() {
        guard statusRefreshTimer == nil else { return }
        let timer = Timer(
            timeInterval: 0.25,
            target: self,
            selector: #selector(refreshStatusItemTimer),
            userInfo: nil,
            repeats: true
        )
        RunLoop.main.add(timer, forMode: .common)
        statusRefreshTimer = timer
    }

    @objc private func refreshStatusItemTimer() {
        updateStatusItem(for: overlayController.activeTargets)
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu(title: "macOS UI Bridge")
        populateMenu(menu)
        return menu
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        updateStatusItem(for: overlayController.activeTargets)
        menu.removeAllItems()
        populateMenu(menu)
    }

    func menuWillOpen(_ menu: NSMenu) {
        updateStatusItem(for: overlayController.activeTargets)
        menu.removeAllItems()
        populateMenu(menu)
    }

    private func refreshMenu() {
        guard let menu = statusItem.menu else { return }
        updateStatusItem(for: overlayController.activeTargets)
        menu.removeAllItems()
        populateMenu(menu)
    }

    private func populateMenu(_ menu: NSMenu) {
        let status = NSMenuItem(title: "服务运行中 · 127.0.0.1:8765", action: nil, keyEquivalent: "")
        status.isEnabled = false
        menu.addItem(status)
        let targets = overlayController.activeTargets
        if !targets.isEmpty {
            menu.addItem(.separator())
            let heading = NSMenuItem(title: "正在操控", action: nil, keyEquivalent: "")
            heading.isEnabled = false
            menu.addItem(heading)
            for target in targets {
                let active = NSMenuItem(title: "  正在操控 \(target.name)", action: nil, keyEquivalent: "")
                active.isEnabled = false
                active.image = NSImage(systemSymbolName: "cursorarrow.rays", accessibilityDescription: nil)
                menu.addItem(active)
            }
        }
        menu.addItem(.separator())
        menu.addItem(item(title: "检查系统权限", action: #selector(checkPermissions)))
        menu.addItem(item(title: "复制 MCP 连接配置", action: #selector(copyConnection)))
        menu.addItem(.separator())
        menu.addItem(item(title: "退出 macOS UI Bridge", action: #selector(quitApp), key: "q"))
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

    private func updateStatusItem(for targets: [ControlledTarget]) {
        let visibleTargets = Array(targets.prefix(3))
        let signature = visibleTargets.isEmpty
            ? "idle"
            : visibleTargets.map { "\($0.pid):\($0.lastSeen.timeIntervalSinceReferenceDate)" }.joined(separator: ",")
        guard signature != statusSignature else { return }
        statusSignature = signature

        guard !targets.isEmpty else {
            statusItem.length = NSStatusItem.squareLength
            statusItem.button?.image = Self.makeMenuBarIcon()
            statusItem.button?.imageScaling = .scaleProportionallyDown
            statusItem.button?.toolTip = "macOS UI Bridge"
            return
        }

        let image = Self.makeActiveMenuBarImage(for: visibleTargets)
        statusItem.length = image.size.width + 4
        statusItem.button?.image = image
        statusItem.button?.imageScaling = .scaleNone
        statusItem.button?.toolTip = "正在操控 " + visibleTargets.map(\.name).joined(separator: "、")
    }

    private static func makeActiveMenuBarImage(for targets: [ControlledTarget]) -> NSImage {
        let iconSize: CGFloat = 18
        let overlap: CGFloat = 6
        let iconWidth = iconSize + CGFloat(max(0, targets.count - 1)) * (iconSize - overlap)
        let width = 7 + iconWidth + 7 + 13 + 7
        let size = NSSize(width: width, height: 24)
        let image = NSImage(size: size)
        image.lockFocus()

        let pill = NSBezierPath(roundedRect: NSRect(origin: .zero, size: size), xRadius: 12, yRadius: 12)
        NSColor.controlAccentColor.withAlphaComponent(0.82).setFill()
        pill.fill()
        NSColor.white.withAlphaComponent(0.24).setStroke()
        pill.lineWidth = 1
        pill.stroke()

        for (index, target) in targets.enumerated().reversed() {
            let x = 7 + CGFloat(index) * (iconSize - overlap)
            let frame = NSRect(x: x, y: 3, width: iconSize, height: iconSize)
            guard let appIcon = NSRunningApplication(processIdentifier: target.pid)?.icon else { continue }
            NSGraphicsContext.saveGraphicsState()
            NSBezierPath(roundedRect: frame, xRadius: 4.5, yRadius: 4.5).addClip()
            appIcon.draw(in: frame, from: .zero, operation: .sourceOver, fraction: 1)
            NSGraphicsContext.restoreGraphicsState()
            NSColor.white.withAlphaComponent(0.78).setStroke()
            let border = NSBezierPath(roundedRect: frame.insetBy(dx: 0.5, dy: 0.5), xRadius: 4, yRadius: 4)
            border.lineWidth = 1
            border.stroke()
        }

        let arrowX = 7 + iconWidth + 8
        let arrow = NSBezierPath()
        arrow.move(to: NSPoint(x: arrowX, y: 18))
        arrow.line(to: NSPoint(x: arrowX, y: 6))
        arrow.line(to: NSPoint(x: arrowX + 10, y: 13))
        arrow.line(to: NSPoint(x: arrowX + 5.5, y: 14))
        arrow.line(to: NSPoint(x: arrowX + 8, y: 19))
        arrow.line(to: NSPoint(x: arrowX + 5, y: 20))
        arrow.line(to: NSPoint(x: arrowX + 2.5, y: 15))
        arrow.close()
        NSColor.white.withAlphaComponent(0.96).setFill()
        arrow.fill()

        image.unlockFocus()
        image.isTemplate = false
        return image
    }
}
