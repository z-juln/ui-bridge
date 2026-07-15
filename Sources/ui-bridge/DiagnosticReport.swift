import Foundation
import UIBridgeMacCore

struct DiagnosticReport: Encodable, Sendable {
    struct Service: Encodable, Sendable {
        let reachable: Bool
        let endpoint: String
    }

    struct Permissions: Encodable, Sendable {
        let accessibility: Bool
        let screenCapture: Bool
    }

    struct Activity: Encodable, Sendable {
        let activeApplicationCount: Int
        let recentEventCount: Int
        let clientNames: [String]
        let phaseCounts: [String: Int]
    }

    struct Preview: Encodable, Sendable {
        let status: String
        let activeStreamCount: Int
        let connectedStreamCount: Int
        let errorCount: Int
        let recentStages: [String]
    }

    struct Privacy: Encodable, Sendable {
        let screenshotsIncluded = false
        let applicationNamesIncluded = false
        let uiContentIncluded = false
        let credentialsIncluded = false
    }

    let schemaVersion = 1
    let generatedAt: Date
    let appVersion: String
    let operatingSystem: String
    let service: Service
    let permissions: Permissions
    let activity: Activity
    let preview: Preview
    let privacy = Privacy()
}

enum DiagnosticReportBuilder {
    static func build(
        serviceReady: Bool,
        permissions: PermissionStatus,
        recentEvents: [AutomationActivityRecord],
        activeApplicationCount: Int,
        previewStatus: String,
        connectedPreviewCount: Int,
        previewErrorCount: Int
    ) -> DiagnosticReport {
        var phaseCounts: [String: Int] = [:]
        for event in recentEvents {
            phaseCounts[event.phase.rawValue, default: 0] += 1
        }
        let clients = Array(Set(recentEvents.compactMap(\.source))).sorted()
        let safeStages = Array(PreviewDiagnosticCenter.recent().suffix(20).map(\.stage))
        return DiagnosticReport(
            generatedAt: Date(),
            appVersion: appVersion,
            operatingSystem: ProcessInfo.processInfo.operatingSystemVersionString,
            service: .init(reachable: serviceReady, endpoint: "127.0.0.1:8765"),
            permissions: .init(
                accessibility: permissions.accessibilityTrusted,
                screenCapture: permissions.screenCaptureAllowed == true
            ),
            activity: .init(
                activeApplicationCount: activeApplicationCount,
                recentEventCount: recentEvents.count,
                clientNames: clients,
                phaseCounts: phaseCounts
            ),
            preview: .init(
                status: safePreviewStatus(previewStatus),
                activeStreamCount: activeApplicationCount,
                connectedStreamCount: connectedPreviewCount,
                errorCount: previewErrorCount,
                recentStages: safeStages
            )
        )
    }

    static func encoded(_ report: DiagnosticReport) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(report)
    }

    static func summary(_ report: DiagnosticReport) -> String {
        let clients = report.activity.clientNames.isEmpty ? "无" : report.activity.clientNames.joined(separator: "、")
        return """
        UI Bridge 诊断摘要
        版本：\(report.appVersion)
        本地服务：\(report.service.reachable ? "正常" : "无法连接")
        辅助功能：\(report.permissions.accessibility ? "正常" : "未授权")
        屏幕录制：\(report.permissions.screenCapture ? "正常" : "未授权")
        最近客户端：\(clients)
        最近事件数：\(report.activity.recentEventCount)
        活动应用数：\(report.activity.activeApplicationCount)
        实时画面：\(report.preview.status)
        画面错误数：\(report.preview.errorCount)
        隐私：不包含截图、应用名称、界面正文和凭据
        """
    }

    private static var appVersion: String {
        let info = Bundle.main.infoDictionary
        return (info?["CFBundleShortVersionString"] as? String)
            ?? (info?["CFBundleVersion"] as? String)
            ?? "0.1.0-dev"
    }

    private static func safePreviewStatus(_ status: String) -> String {
        let allowed = ["等待活动", "实时画面已暂停", "实时画面已连接", "部分窗口无法显示"]
        if allowed.contains(status) { return status }
        if status.hasPrefix("正在连接 ") { return "正在连接窗口" }
        return "未知"
    }
}
