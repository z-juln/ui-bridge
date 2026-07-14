import Darwin
import Foundation
import UIBridgeMacCore

@main
enum SafetySelfTest {
    static func main() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("app-mcp-bridge-safety-\(UUID().uuidString)", isDirectory: true)
        setenv("APP_MCP_BRIDGE_CONFIRMATION_DIR", directory.path, 1)
        setenv("APP_MCP_BRIDGE_ACCESS_POLICY_PATH", directory.appendingPathComponent("app-access.json").path, 1)
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
        print("safety-self-test: 6 checks passed")
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
