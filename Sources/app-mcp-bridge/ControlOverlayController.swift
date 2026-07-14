import AppKit
import CoreGraphics
import UIBridgeMacCore
import UIBridgeProtocol

struct ControlledTarget: Sendable {
    let pid: Int32
    let name: String
    let windowID: UInt32
    let windowBounds: UIBRect
    let pointer: UIBPoint?
    let phase: AutomationActivityPhase
    let action: String
    let source: String
    let lastSeen: Date
}

@MainActor
final class ControlOverlayController: NSObject {
    private static let targetRetention: TimeInterval = 90
    private static let visualFeedbackFreshness: TimeInterval = 3

    private struct TargetState {
        var name: String
        var record: AutomationActivityRecord
        var lastSeen: Date
        var badgePanel: NSPanel
        var cursorPanel: NSPanel?
        var hideBadge: Timer?
        var hideCursor: Timer?
        var expireTarget: Timer?
    }

    private var targets: [Int32: TargetState] = [:]
    private var pollTimer: Timer?
    private var lastEventID: String?
    var onTargetsChanged: (() -> Void)?

    override init() {
        super.init()
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(receiveActivity(_:)),
            name: AutomationActivityCenter.notification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(receiveLocalActivity(_:)),
            name: AutomationActivityCenter.notification,
            object: nil
        )
    }

    func startPolling() {
        guard pollTimer == nil else { return }
        let pollTimer = Timer(
            timeInterval: 0.12,
            target: self,
            selector: #selector(pollActivity),
            userInfo: nil,
            repeats: true
        )
        RunLoop.main.add(pollTimer, forMode: .common)
        self.pollTimer = pollTimer
    }

    deinit {
        DistributedNotificationCenter.default().removeObserver(self)
        NotificationCenter.default.removeObserver(self)
    }

    var activeTargets: [ControlledTarget] {
        recoverLatestTarget()
        let cutoff = Date().addingTimeInterval(-Self.targetRetention)
        return targets.compactMap { pid, state in
            guard state.lastSeen >= cutoff else { return nil }
            guard let runningApp = NSRunningApplication(processIdentifier: pid),
                  runningApp.bundleIdentifier != "com.juln.app-mcp-bridge" else { return nil }
            return ControlledTarget(
                pid: pid,
                name: state.name,
                windowID: state.record.windowID,
                windowBounds: state.record.windowBounds,
                pointer: state.record.pointer,
                phase: state.record.phase,
                action: state.record.action ?? "读取界面",
                source: state.record.source ?? "本地 MCP",
                lastSeen: state.lastSeen
            )
        }.sorted { $0.lastSeen > $1.lastSeen }
    }

    @objc private func receiveActivity(_ notification: Notification) {
        consumeLatest()
    }

    @objc nonisolated private func receiveLocalActivity(_ notification: Notification) {
        performSelector(
            onMainThread: #selector(receiveActivityOnMainThread),
            with: nil,
            waitUntilDone: false,
            modes: [RunLoop.Mode.common.rawValue]
        )
    }

    @objc private func receiveActivityOnMainThread() {
        consumeLatest()
    }

    @objc private func pollActivity() {
        consumeLatest()
    }

    private func consumeLatest() {
        guard let record = AutomationActivityCenter.latest(),
              record.eventID != lastEventID else { return }
        lastEventID = record.eventID
        guard retainTarget(record) else { return }
        scheduleExpiration(for: record)
        onTargetsChanged?()
        if record.createdAt > Date().addingTimeInterval(-Self.visualFeedbackFreshness) {
            display(record)
        }
    }

    private func recoverLatestTarget() {
        guard let record = AutomationActivityCenter.latest() else { return }
        _ = retainTarget(record)
    }

    @discardableResult
    private func retainTarget(_ record: AutomationActivityRecord) -> Bool {
        guard record.createdAt > Date().addingTimeInterval(-Self.targetRetention) else { return false }
        let badgePanel = targets[record.pid]?.badgePanel ?? Self.makeBadgePanel()
        var state = targets[record.pid] ?? TargetState(
            name: record.appName,
            record: record,
            lastSeen: record.createdAt,
            badgePanel: badgePanel
        )
        state.name = record.appName
        state.record = record
        state.lastSeen = max(state.lastSeen, record.createdAt)
        targets[record.pid] = state
        return true
    }

    private func scheduleExpiration(for record: AutomationActivityRecord) {
        guard var state = targets[record.pid] else { return }
        state.expireTarget?.invalidate()
        let timer = Timer(
            timeInterval: max(0.1, record.createdAt.addingTimeInterval(Self.targetRetention).timeIntervalSinceNow),
            target: self,
            selector: #selector(expireTargetTimer(_:)),
            userInfo: NSNumber(value: record.pid),
            repeats: false
        )
        state.expireTarget = timer
        targets[record.pid] = state
        RunLoop.main.add(timer, forMode: .common)
    }

    private func display(_ record: AutomationActivityRecord) {
        let phase = record.phase
        let pid = record.pid
        let appName = record.appName
        let quartzBounds = CGRect(
            x: record.windowBounds.origin.x,
            y: record.windowBounds.origin.y,
            width: record.windowBounds.size.width,
            height: record.windowBounds.size.height
        )
        let screenBounds = Self.appKitRect(fromQuartz: quartzBounds)
        let badgePanel = targets[pid]?.badgePanel ?? Self.makeBadgePanel()
        var state = targets[pid] ?? TargetState(name: appName, record: record, lastSeen: record.createdAt, badgePanel: badgePanel)
        state.name = appName
        state.record = record
        state.lastSeen = max(state.lastSeen, record.createdAt)
        state.hideBadge?.invalidate()

        let targetIsFrontmost = NSWorkspace.shared.frontmostApplication?.processIdentifier == pid
        let targetWindowIsVisible = WindowDiscovery.listWindows(pid: pid).contains {
            $0.windowID == record.windowID && $0.isVisible
        }
        guard targetIsFrontmost && targetWindowIsVisible else {
            state.badgePanel.orderOut(nil)
            state.cursorPanel?.orderOut(nil)
            targets[pid] = state
            return
        }

        let badgeSize = badgePanel.frame.size
        badgePanel.setFrameOrigin(NSPoint(
            x: screenBounds.minX + 14,
            y: screenBounds.maxY - badgeSize.height - 14
        ))
        badgePanel.orderFrontRegardless()

        let hideBadge = Timer(
            timeInterval: phase == .actionStarted ? 2.2 : 1.4,
            target: self,
            selector: #selector(hideBadgeTimer(_:)),
            userInfo: NSNumber(value: pid),
            repeats: false
        )
        state.hideBadge = hideBadge
        RunLoop.main.add(hideBadge, forMode: .common)

        if phase != .observed, let pointer = record.pointer {
            state.hideCursor?.invalidate()
            let cursorPanel = state.cursorPanel ?? Self.makeCursorPanel()
            let point = Self.appKitPoint(fromQuartz: CGPoint(x: pointer.x, y: pointer.y))
            cursorPanel.setFrameOrigin(NSPoint(
                x: point.x - cursorPanel.frame.width / 2,
                y: point.y - cursorPanel.frame.height / 2
            ))
            cursorPanel.orderFrontRegardless()
            state.cursorPanel = cursorPanel
        }

        if phase == .actionFinished, state.cursorPanel != nil {
            state.hideCursor?.invalidate()
            let hideCursor = Timer(
                timeInterval: 0.85,
                target: self,
                selector: #selector(hideCursorTimer(_:)),
                userInfo: NSNumber(value: pid),
                repeats: false
            )
            state.hideCursor = hideCursor
            RunLoop.main.add(hideCursor, forMode: .common)
        }
        targets[pid] = state
    }

    @objc private func hideBadgeTimer(_ timer: Timer) {
        guard let pid = (timer.userInfo as? NSNumber)?.int32Value else { return }
        targets[pid]?.badgePanel.orderOut(nil)
    }

    @objc private func hideCursorTimer(_ timer: Timer) {
        guard let pid = (timer.userInfo as? NSNumber)?.int32Value else { return }
        targets[pid]?.cursorPanel?.orderOut(nil)
    }

    @objc private func expireTargetTimer(_ timer: Timer) {
        guard let pid = (timer.userInfo as? NSNumber)?.int32Value,
              let state = targets[pid],
              state.lastSeen <= Date().addingTimeInterval(-Self.targetRetention) else { return }
        state.badgePanel.orderOut(nil)
        state.cursorPanel?.orderOut(nil)
        targets.removeValue(forKey: pid)
        onTargetsChanged?()
    }

    private static func makeBadgePanel() -> NSPanel {
        makePanel(size: NSSize(width: 112, height: 34), content: ControlBadgeView(frame: NSRect(x: 0, y: 0, width: 112, height: 34)))
    }

    private static func makeCursorPanel() -> NSPanel {
        makePanel(size: NSSize(width: 128, height: 128), content: SimulatedCursorView(frame: NSRect(x: 0, y: 0, width: 128, height: 128)))
    }

    private static func makePanel(size: NSSize, content: NSView) -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.level = .statusBar
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.contentView = content
        return panel
    }

    private static func appKitPoint(fromQuartz point: CGPoint) -> NSPoint {
        for screen in NSScreen.screens {
            guard let id = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else { continue }
            let quartz = CGDisplayBounds(id)
            if quartz.contains(point) {
                return NSPoint(
                    x: screen.frame.minX + point.x - quartz.minX,
                    y: screen.frame.maxY - (point.y - quartz.minY)
                )
            }
        }
        let primaryMaxY = NSScreen.screens.first?.frame.maxY ?? 0
        return NSPoint(x: point.x, y: primaryMaxY - point.y)
    }

    private static func appKitRect(fromQuartz rect: CGRect) -> NSRect {
        let topLeft = appKitPoint(fromQuartz: rect.origin)
        let bottomRight = appKitPoint(fromQuartz: CGPoint(x: rect.maxX, y: rect.maxY))
        return NSRect(
            x: min(topLeft.x, bottomRight.x),
            y: min(topLeft.y, bottomRight.y),
            width: abs(bottomRight.x - topLeft.x),
            height: abs(topLeft.y - bottomRight.y)
        )
    }
}

private final class ControlBadgeView: NSView {
    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let pill = bounds.insetBy(dx: 1, dy: 1)
        let background = NSBezierPath(roundedRect: pill, xRadius: 16, yRadius: 16)
        NSColor(calibratedRed: 0.34, green: 0.26, blue: 0.94, alpha: 0.96).setFill()
        background.fill()
        NSColor.white.withAlphaComponent(0.25).setStroke()
        background.lineWidth = 1
        background.stroke()

        NSColor.white.setStroke()
        for rect in [NSRect(x: 15, y: 10, width: 20, height: 13), NSRect(x: 27, y: 14, width: 13, height: 10)] {
            let path = NSBezierPath(roundedRect: rect, xRadius: 2.5, yRadius: 2.5)
            path.lineWidth = 2
            path.stroke()
        }
        let text = "操作中" as NSString
        text.draw(at: NSPoint(x: 48, y: 8), withAttributes: [
            .font: NSFont.systemFont(ofSize: 13, weight: .semibold),
            .foregroundColor: NSColor.white,
        ])
    }
}

private final class SimulatedCursorView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let center = NSPoint(x: bounds.midX, y: bounds.midY)
        for radius in stride(from: 62.0, through: 26.0, by: -2.0) {
            let progress = (62 - radius) / 36
            let alpha = 0.012 + progress * 0.038
            NSColor(calibratedRed: 0.12, green: 0.58, blue: 0.96, alpha: alpha).setFill()
            NSBezierPath(ovalIn: NSRect(
                x: center.x - radius, y: center.y - radius,
                width: radius * 2, height: radius * 2
            )).fill()
        }
        NSColor(calibratedRed: 0.24, green: 0.56, blue: 0.95, alpha: 0.42).setFill()
        NSBezierPath(ovalIn: NSRect(x: center.x - 31, y: center.y - 31, width: 62, height: 62)).fill()

        let arrow = NSBezierPath()
        arrow.move(to: NSPoint(x: center.x - 9, y: center.y + 14))
        arrow.line(to: NSPoint(x: center.x - 9, y: center.y - 15))
        arrow.line(to: NSPoint(x: center.x + 14, y: center.y + 2))
        arrow.line(to: NSPoint(x: center.x + 3, y: center.y + 4))
        arrow.line(to: NSPoint(x: center.x + 8, y: center.y + 15))
        arrow.close()
        NSColor.white.withAlphaComponent(0.92).setFill()
        NSColor(calibratedRed: 0.16, green: 0.42, blue: 0.74, alpha: 0.9).setStroke()
        arrow.lineWidth = 2
        arrow.fill()
        arrow.stroke()
    }
}
