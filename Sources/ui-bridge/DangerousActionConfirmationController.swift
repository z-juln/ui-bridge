import AppKit
import UIBridgeMacCore

@MainActor
final class DangerousActionConfirmationController: NSObject {
    private let model: BridgeSettingsModel
    private var timer: Timer?
    private var handled = Set<String>()
    private var activeAlert: NSAlert?
    private var activeRequestID: String?
    private var alertTimeoutTimer: Timer?

    init(model: BridgeSettingsModel) {
        self.model = model
        super.init()
    }

    func start() {
        guard timer == nil else { return }
        DangerousActionConfirmationCenter.writeHeartbeat()
        let timer = Timer(
            timeInterval: 0.25,
            target: self,
            selector: #selector(poll),
            userInfo: nil,
            repeats: true
        )
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    @objc private func poll() {
        DangerousActionConfirmationCenter.writeHeartbeat()
        guard let request = DangerousActionConfirmationCenter.pendingRequests().first(where: { !handled.contains($0.id) }) else { return }
        handled.insert(request.id)
        model.pendingDangerousRequest = request
        present(request)
    }

    private func present(_ request: DangerousActionConfirmationRequest) {
        NSApplication.shared.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.alertStyle = .critical
        alert.messageText = "确认\(request.category.displayName)操作？"
        alert.informativeText = "目标应用：\(request.appName)\n具体动作：\(request.action)\n目标：\(request.target)\n可能影响：\(request.impact)\n\n只允许弹窗中这一项操作；关闭、拒绝或超时都不会执行。"
        alert.addButton(withTitle: "取消操作")
        alert.addButton(withTitle: "我已了解，允许这一次")

        activeAlert = alert
        activeRequestID = request.id
        let timeoutTimer = Timer(
            fireAt: request.expiresAt,
            interval: 0,
            target: self,
            selector: #selector(expireActiveAlert(_:)),
            userInfo: request.id,
            repeats: false
        )
        RunLoop.main.add(timeoutTimer, forMode: .common)
        alertTimeoutTimer = timeoutTimer

        let result = alert.runModal()
        timeoutTimer.invalidate()
        alertTimeoutTimer = nil
        activeAlert = nil
        activeRequestID = nil
        let approved = result == .alertSecondButtonReturn && Date() < request.expiresAt
        DangerousActionConfirmationCenter.respond(to: request, approved: approved)
        model.pendingDangerousRequest = nil
    }

    @objc private func expireActiveAlert(_ timer: Timer) {
        guard let requestID = timer.userInfo as? String,
              requestID == activeRequestID,
              let alert = activeAlert else { return }
        NSApplication.shared.abortModal()
        alert.window.orderOut(nil)
    }
}
