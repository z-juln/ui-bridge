import Darwin
import Foundation
import UIBridgeMacCore
import UIBridgeProtocol

@main
enum SafetySelfTest {
    static func main() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ui-bridge-safety-\(UUID().uuidString)", isDirectory: true)
        setenv("UI_BRIDGE_CONFIRMATION_DIR", directory.path, 1)
        setenv("UI_BRIDGE_ACCESS_POLICY_PATH", directory.appendingPathComponent("app-access.json").path, 1)
        defer { try? FileManager.default.removeItem(at: directory) }

        DangerousActionConfirmationCenter.writeHeartbeat()
        let approvedTask = Task {
            await DangerousActionConfirmationCenter.requestApproval(
                category: .deletion,
                appName: "测试应用",
                action: "删除测试项目",
                target: "测试项目",
                impact: "测试项目将被删除",
                timeout: 3
            )
        }
        let approvedRequest = try await waitForRequest()
        guard approvedRequest.category == .deletion else { throw Failure("category was not preserved") }
        DangerousActionConfirmationCenter.respond(to: approvedRequest, approved: true)
        guard await approvedTask.value else { throw Failure("approved request did not continue") }

        DangerousActionConfirmationCenter.writeHeartbeat()
        let deniedTask = Task {
            await DangerousActionConfirmationCenter.requestApproval(
                category: .permissionChange,
                appName: "测试应用",
                action: "改变测试权限",
                target: "测试权限",
                impact: "测试权限将改变",
                timeout: 3
            )
        }
        let deniedRequest = try await waitForRequest()
        DangerousActionConfirmationCenter.respond(to: deniedRequest, approved: false)
        guard await deniedTask.value == false else { throw Failure("denied request continued") }

        DangerousActionConfirmationCenter.writeHeartbeat()
        let timeoutStartedAt = Date()
        let timedOut = await DangerousActionConfirmationCenter.requestApproval(
            category: .purchase,
            appName: "测试应用",
            action: "购买测试项目",
            target: "测试项目",
            impact: "会产生测试费用",
            timeout: 0.4
        )
        guard timedOut == false else { throw Failure("timed out request continued") }
        guard Date().timeIntervalSince(timeoutStartedAt) < 2 else {
            throw Failure("timed out request did not fail closed promptly")
        }

        try FileManager.default.removeItem(at: DangerousActionConfirmationCenter.heartbeatURL)
        let unavailable = await DangerousActionConfirmationCenter.requestApproval(
            category: .purchase,
            appName: "测试应用",
            action: "购买测试项目",
            target: "测试项目",
            impact: "会产生费用",
            timeout: 1
        )
        guard unavailable == false else { throw Failure("request continued without App heartbeat") }

        try AppAccessPolicyStore.save(AppAccessPolicy(defaultAllow: false))
        guard AppAccessPolicyStore.load().allows(appID: "com.example.blocked") == false else {
            throw Failure("default block policy was not applied")
        }
        try AppAccessPolicyStore.setAllowed(true, appID: "com.example.allowed")
        guard AppAccessPolicyStore.load().allows(appID: "com.example.allowed") else {
            throw Failure("per-app allow policy was not applied")
        }
        try AppAccessPolicyStore.setAllowed(nil, appID: "com.example.allowed")
        guard AppAccessPolicyStore.load().allows(appID: "com.example.allowed") == false else {
            throw Failure("inherited app policy was not restored")
        }
        let visible = VisualTextRegion(
            text: "普通文字",
            confidence: 1,
            screenshotFrame: UIBRect(x: 20, y: 20, width: 60, height: 20),
            windowFrame: UIBRect(x: 10, y: 10, width: 30, height: 10)
        )
        let secret = VisualTextRegion(
            text: "secret-value",
            confidence: 1,
            screenshotFrame: UIBRect(x: 200, y: 200, width: 120, height: 20),
            windowFrame: UIBRect(x: 100, y: 100, width: 60, height: 10)
        )
        let filtered = VisualTextPrivacyFilter.excludingSecureRegions(
            [visible, secret],
            secureFrames: [UIBRect(x: 90, y: 90, width: 100, height: 40)]
        )
        guard filtered == [visible] else { throw Failure("visual text from a secure field was not excluded") }
        print("safety-self-test: 8 checks passed")
    }

    private static func waitForRequest() async throws -> DangerousActionConfirmationRequest {
        for _ in 0..<30 {
            if let request = DangerousActionConfirmationCenter.pendingRequests().first { return request }
            try await Task.sleep(for: .milliseconds(50))
        }
        throw Failure("confirmation request did not appear")
    }
}

private struct Failure: LocalizedError {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}
