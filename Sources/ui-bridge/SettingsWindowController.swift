import AppKit
import SwiftUI
import UIBridgeMacCore
import UIBridgeServer
import UniformTypeIdentifiers

@MainActor
final class BridgeSettingsModel: NSObject, ObservableObject {
    @Published var selectedSection: SettingsSection = .overview {
        didSet {
            session.setViewerActive(windowVisible && selectedSection == .liveControl)
        }
    }
    @Published var permissions = PermissionInspector.current()
    @Published var serviceReady = false
    @Published var serviceDetail = "正在检查"
    @Published var diagnosticsFeedback: String?
    @Published var lastRefreshed = Date()
    @Published var selectedTargetPID: Int32?
    @Published var recentEvents: [AutomationActivityRecord] = []
    @Published var operationsStopped = false
    @Published var pendingDangerousRequest: DangerousActionConfirmationRequest?
    @Published var runningApps = AppDiscovery.listRunningApplications()
    @Published var accessPolicy = AppAccessPolicyStore.load()

    let session: AutomationSessionCoordinator
    private let token: String

    init(token: String, session: AutomationSessionCoordinator) {
        self.token = token
        self.session = session
        super.init()
    }

    let connectionURL = "http://127.0.0.1:8765/mcp"

    var activeTargets: [ControlledTarget] { session.targets }

    func refresh(targets: [ControlledTarget]? = nil) {
        permissions = PermissionInspector.current()
        if let targets { session.updateTargets(targets) }
        recentEvents = AutomationActivityCenter.recent()
        runningApps = AppDiscovery.listRunningApplications()
        accessPolicy = AppAccessPolicyStore.load()
        serviceReady = ServiceStateStore().runningPID() == getpid()
        serviceDetail = serviceReady ? "响应正常" : "服务记录不可用"
        if selectedTargetPID == nil || !session.targets.contains(where: { $0.pid == selectedTargetPID }) {
            selectedTargetPID = session.targets.first?.pid
        }
        lastRefreshed = Date()
    }

    func copyDiagnosticSummary() {
        let report = makeDiagnosticReport()
        NSPasteboard.general.clearContents()
        if NSPasteboard.general.setString(DiagnosticReportBuilder.summary(report), forType: .string) {
            diagnosticsFeedback = "诊断摘要已复制"
        } else {
            diagnosticsFeedback = "复制失败"
        }
    }

    func exportDiagnosticReport() {
        let panel = NSSavePanel()
        panel.title = "导出脱敏诊断报告"
        panel.nameFieldStringValue = "ui-bridge-diagnostics.json"
        panel.allowedContentTypes = [.json]
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try DiagnosticReportBuilder.encoded(makeDiagnosticReport()).write(to: url, options: .atomic)
            diagnosticsFeedback = "诊断报告已导出"
        } catch {
            diagnosticsFeedback = "导出失败"
        }
    }

    func makeDiagnosticReport() -> DiagnosticReport {
        DiagnosticReportBuilder.build(
            serviceReady: serviceReady,
            permissions: permissions,
            recentEvents: recentEvents,
            activeApplicationCount: session.targets.count,
            previewStatus: session.status,
            connectedPreviewCount: session.frames.count,
            previewErrorCount: session.errors.count
        )
    }


    func setDefaultAppAccess(_ allowed: Bool) {
        try? AppAccessPolicyStore.setDefaultAllow(allowed)
        accessPolicy = AppAccessPolicyStore.load()
    }

    func setAppAccess(_ allowed: Bool?, appID: String) {
        try? AppAccessPolicyStore.setAllowed(allowed, appID: appID)
        accessPolicy = AppAccessPolicyStore.load()
    }

    func setWindowVisible(_ visible: Bool) {
        windowVisible = visible
        session.setViewerActive(visible && selectedSection == .liveControl)
    }

    private var windowVisible = false
    func beginLivePreview() {
        session.setViewerActive(windowVisible && selectedSection == .liveControl)
    }

    func endLivePreview() {
        session.setViewerActive(false)
    }

    func stopAllOperations() async {
        do {
            _ = try await LocalBridgeClient(token: token).call(tool: "emergency_stop", argumentsJSON: nil)
            operationsStopped = true
            session.clear()
        } catch {
            // The diagnostics page will still expose a stopped or unreachable service.
        }
    }
}

enum SettingsSection: String, CaseIterable, Identifiable {
    case overview
    case liveControl
    case permissions
    case connections
    case appAccess
    case safety
    case diagnostics

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview: "总览"
        case .liveControl: "实时操控"
        case .permissions: "系统权限"
        case .connections: "连接"
        case .appAccess: "应用访问"
        case .safety: "操作安全"
        case .diagnostics: "调试与诊断"
        }
    }

    var symbol: String {
        switch self {
        case .overview: "square.grid.2x2"
        case .liveControl: "rectangle.inset.filled.and.cursorarrow"
        case .permissions: "checkmark.shield"
        case .connections: "cable.connector"
        case .appAccess: "app.badge.checkmark"
        case .safety: "exclamationmark.shield"
        case .diagnostics: "waveform.path.ecg.rectangle"
        }
    }
}

@MainActor
final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    let model: BridgeSettingsModel

    init(model: BridgeSettingsModel) {
        self.model = model
        let content = SettingsRootView(model: model)
        let hosting = NSHostingController(rootView: content)
        let window = NSWindow(contentViewController: hosting)
        window.title = "UI Bridge"
        window.setContentSize(NSSize(width: 1_080, height: 720))
        window.minSize = NSSize(width: 900, height: 600)
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.center()
        window.isReleasedWhenClosed = false
        super.init(window: window)
        window.delegate = self
    }

    required init?(coder: NSCoder) { nil }

    func show(section: SettingsSection? = nil, targets: [ControlledTarget], activate: Bool = true) {
        if let section { model.selectedSection = section }
        model.refresh(targets: targets)
        window?.centerIfNeeded()
        if activate {
            showWindow(nil)
            NSApplication.shared.activate(ignoringOtherApps: true)
            window?.makeKeyAndOrderFront(nil)
        } else {
            window?.orderBack(nil)
        }
        model.setWindowVisible(true)
    }

    func windowWillClose(_ notification: Notification) {
        model.setWindowVisible(false)
    }
}

private extension NSWindow {
    func centerIfNeeded() {
        guard !isVisible else { return }
        center()
    }
}
