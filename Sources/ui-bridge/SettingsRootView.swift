import AppKit
import SwiftUI
import UIBridgeMacCore

struct SettingsRootView: View {
    @ObservedObject var model: BridgeSettingsModel

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 210, ideal: 230, max: 260)
        } detail: {
            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(nsColor: .windowBackgroundColor))
        }
        .frame(minWidth: 900, minHeight: 600)
        .toolbar(removing: .sidebarToggle)
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(nsImage: NSApplication.shared.applicationIconImage)
                    .resizable()
                    .frame(width: 34, height: 34)
                VStack(alignment: .leading, spacing: 1) {
                    Text("UI Bridge").font(.headline)
                    Text("本机应用操控中心").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 18)
            .padding(.bottom, 14)

            List(SettingsSection.allCases, selection: $model.selectedSection) { section in
                Label(section.title, systemImage: section.symbol)
                    .tag(section)
                    .padding(.vertical, 3)
            }
            .listStyle(.sidebar)

            Divider()
            HStack(spacing: 7) {
                Circle().fill(.green).frame(width: 8, height: 8)
                Text("服务运行中").font(.caption)
                Spacer()
            }
            .foregroundStyle(.secondary)
            .padding(14)
        }
    }

    @ViewBuilder
    private var detail: some View {
        switch model.selectedSection {
        case .overview: OverviewSettingsView(model: model)
        case .liveControl: LiveControlView(model: model, session: model.session)
        case .permissions: PermissionSettingsView(model: model)
        case .connections: ConnectionSettingsView(model: model)
        case .appAccess: AppAccessSettingsView(model: model)
        case .safety: SafetySettingsView(model: model)
        case .diagnostics: DiagnosticsSettingsView(model: model)
        }
    }
}

private struct PageContainer<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(title).font(.system(size: 28, weight: .bold))
                    Text(subtitle).foregroundStyle(.secondary)
                }
                content
            }
            .frame(maxWidth: 860, alignment: .leading)
            .padding(34)
        }
    }
}

private struct SettingsCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.background, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(.separator.opacity(0.65)))
    }
}

private struct StatusRow: View {
    let symbol: String
    let title: String
    let detail: String
    let ready: Bool

    var body: some View {
        HStack(spacing: 13) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(ready ? .green : .orange)
                .frame(width: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).fontWeight(.medium)
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text(ready ? "正常" : "需要处理")
                .font(.caption.weight(.semibold))
                .foregroundStyle(ready ? .green : .orange)
                .padding(.horizontal, 9).padding(.vertical, 5)
                .background((ready ? Color.green : Color.orange).opacity(0.1), in: Capsule())
        }
    }
}

private struct OverviewSettingsView: View {
    @ObservedObject var model: BridgeSettingsModel

    var body: some View {
        PageContainer(title: "总览", subtitle: "查看 Bridge 当前是否可用，以及最近正在操作哪些应用。") {
            HStack(spacing: 14) {
                metric(title: "服务", value: "运行中", symbol: "bolt.horizontal.circle.fill", color: .green)
                metric(title: "系统权限", value: permissionSummary, symbol: "checkmark.shield.fill", color: permissionsReady ? .green : .orange)
                metric(title: "活动应用", value: "\(model.activeTargets.count)", symbol: "rectangle.stack.badge.play.fill", color: .blue)
            }

            SettingsCard {
                VStack(spacing: 16) {
                    StatusRow(symbol: "accessibility", title: "辅助功能", detail: "读取控件并执行经过允许的操作", ready: model.permissions.accessibilityTrusted)
                    Divider()
                    StatusRow(symbol: "rectangle.on.rectangle", title: "屏幕录制", detail: "获取目标窗口画面用于理解与调试", ready: model.permissions.screenCaptureAllowed == true)
                }
            }

            SettingsCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("最近活动").font(.headline)
                    if model.activeTargets.isEmpty {
                        ContentUnavailableView("暂无操控活动", systemImage: "cursorarrow.motionlines", description: Text("Agent 读取或操作应用后，会在这里出现。"))
                            .frame(maxWidth: .infinity, minHeight: 130)
                    } else {
                        ForEach(model.activeTargets, id: \.pid) { target in
                            HStack(spacing: 12) {
                                AppIconView(pid: target.pid, size: 32)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(target.name).fontWeight(.medium)
                                    Text(target.lastSeen, style: .relative).font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text("正在操控").font(.caption.weight(.semibold)).foregroundStyle(.blue)
                            }
                        }
                    }
                }
            }
        }
    }

    private var permissionsReady: Bool { model.permissions.accessibilityTrusted && model.permissions.screenCaptureAllowed == true }
    private var permissionSummary: String { permissionsReady ? "已就绪" : "待处理" }

    private func metric(title: String, value: String, symbol: String, color: Color) -> some View {
        SettingsCard {
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: symbol).font(.title2).foregroundStyle(color)
                Text(value).font(.title3.bold())
                Text(title).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

private struct LiveControlView: View {
    @ObservedObject var model: BridgeSettingsModel
    @ObservedObject var session: AutomationSessionCoordinator

    var body: some View {
        PageContainer(title: "实时操控", subtitle: "查看当前被 Agent 读取或操作的应用。") {
            if model.operationsStopped {
                Label("所有操作已停止。重新启动 App 后才会恢复。", systemImage: "stop.circle.fill")
                    .foregroundStyle(.red)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
            }

            if session.targets.isEmpty {
                SettingsCard {
                    ContentUnavailableView("等待操控活动", systemImage: "rectangle.inset.filled.and.cursorarrow", description: Text("有应用被读取或操作后，这里会显示实时画面和动作。"))
                        .frame(maxWidth: .infinity, minHeight: 360)
                }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(session.targets, id: \.pid) { target in
                            Button {
                                model.selectedTargetPID = target.pid
                            } label: {
                                VStack(alignment: .leading, spacing: 8) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 8).fill(Color.black.opacity(0.06))
                                        if let image = session.frames[target.pid] {
                                            Image(nsImage: image).resizable().aspectRatio(contentMode: .fit)
                                        } else {
                                            ProgressView()
                                        }
                                    }
                                    .frame(width: 176, height: 104)
                                    HStack(spacing: 7) {
                                        AppIconView(pid: target.pid, size: 22)
                                        Text(target.name).lineLimit(1)
                                        Spacer()
                                        Circle().fill(.green).frame(width: 7, height: 7)
                                    }
                                    .font(.caption.weight(.medium))
                                }
                                .padding(8)
                                .background(.background, in: RoundedRectangle(cornerRadius: 12))
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(model.selectedTargetPID == target.pid ? Color.accentColor : Color.secondary.opacity(0.2), lineWidth: model.selectedTargetPID == target.pid ? 2 : 1))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                if let target = selectedTarget {
                    HStack(alignment: .top, spacing: 14) {
                        SettingsCard {
                            VStack(alignment: .leading, spacing: 13) {
                                HStack {
                                    AppIconView(pid: target.pid, size: 32)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(target.name).font(.headline)
                                        Text("\(target.source) · \(target.action)").font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Label("实时", systemImage: "dot.radiowaves.left.and.right").foregroundStyle(.green)
                                }
                                WindowPreviewView(target: target, image: session.frames[target.pid], error: session.errors[target.pid])
                                    .frame(minHeight: 340)
                            }
                        }

                        VStack(spacing: 14) {
                            SettingsCard {
                                VStack(alignment: .leading, spacing: 0) {
                                    Text("客户端 → Bridge → 应用").font(.headline).padding(.bottom, 5)
                                    ForEach(routeEvents, id: \.eventID) { event in
                                        compactRouteRow(event)
                                        if event.eventID != routeEvents.last?.eventID { Divider() }
                                    }
                                }
                            }
                            SettingsCard {
                                VStack(alignment: .leading, spacing: 0) {
                                    Text("实时事件").font(.headline).padding(.bottom, 5)
                                    ForEach(Array(model.recentEvents.suffix(5).reversed()), id: \.eventID) { event in
                                        compactEventRow(event)
                                        if event.eventID != model.recentEvents.suffix(5).first?.eventID { Divider() }
                                    }
                                }
                            }
                        }
                        .frame(width: 330)
                    }
                }

                HStack {
                    Text("\(session.status) · 关闭窗口或离开本页后，实时画面会停止刷新。")
                        .font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button("停止所有操作", role: .destructive) {
                        Task { await model.stopAllOperations() }
                    }
                    .disabled(model.operationsStopped)
                }
            }
        }
        .onAppear { model.beginLivePreview() }
        .onDisappear { model.endLivePreview() }
    }

    private var selectedTarget: ControlledTarget? {
        session.targets.first { $0.pid == model.selectedTargetPID } ?? session.targets.first
    }

    private var routeEvents: [AutomationActivityRecord] {
        var keys = Set<String>()
        var result: [AutomationActivityRecord] = []
        for event in model.recentEvents.reversed() {
            let key = "\(event.source ?? "本地 MCP"):\(event.pid)"
            guard keys.insert(key).inserted else { continue }
            result.append(event)
            if result.count == 4 { break }
        }
        return result
    }

    private func clientBadge(_ source: String?) -> some View {
        let name = source ?? "MCP"
        return Text(String(name.prefix(1)).uppercased())
            .font(.headline)
            .frame(width: 38, height: 38)
            .background(Color.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
    }

    private func compactRouteRow(_ event: AutomationActivityRecord) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 8) {
                clientBadge(event.source)
                VStack(alignment: .leading, spacing: 1) {
                    Text(event.source ?? "本地 MCP").font(.caption.weight(.semibold)).lineLimit(1)
                    Text("经 UI Bridge").font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "arrow.right").foregroundStyle(.secondary)
                AppIconView(pid: event.pid, size: 26)
                Text(event.appName).font(.caption.weight(.semibold)).lineLimit(1)
            }
            HStack {
                Text(eventDetail(event)).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                Spacer()
                Text(phaseLabel(event.phase))
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(phaseColor(event.phase))
                    .padding(.horizontal, 7).padding(.vertical, 3)
                    .background(phaseColor(event.phase).opacity(0.1), in: Capsule())
            }
        }
        .padding(.vertical, 8)
    }

    private func compactEventRow(_ event: AutomationActivityRecord) -> some View {
        HStack(spacing: 8) {
            Text(event.createdAt, style: .time)
                .font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
                .frame(width: 54, alignment: .leading)
            VStack(alignment: .leading, spacing: 1) {
                Text(event.source ?? "本地 MCP").font(.caption.weight(.semibold)).lineLimit(1)
                Text(eventDescription(event)).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            Circle().fill(phaseColor(event.phase)).frame(width: 7, height: 7)
        }
        .padding(.vertical, 7)
    }

    private func phaseLabel(_ phase: AutomationActivityPhase) -> String {
        switch phase {
        case .observed: "只读"
        case .confirmationRequested: "待确认"
        case .confirmationRejected: "已取消"
        case .actionStarted: "执行中"
        case .actionFinished: "已复查"
        }
    }

    private func phaseColor(_ phase: AutomationActivityPhase) -> Color {
        switch phase {
        case .observed, .actionStarted: .blue
        case .actionFinished: .green
        case .confirmationRequested: .orange
        case .confirmationRejected: .red
        }
    }

    private func eventDescription(_ event: AutomationActivityRecord) -> String {
        switch event.phase {
        case .observed: "读取了 \(event.appName) 的窗口"
        case .confirmationRequested: "请求在 \(event.appName) 执行高影响操作"
        case .confirmationRejected: "取消了 \(event.appName) 的高影响操作"
        case .actionStarted: "正在对 \(event.appName) 执行 \(event.action ?? "操作")"
        case .actionFinished: "完成 \(event.appName) 的操作并重新读取"
        }
    }

    private func eventDetail(_ event: AutomationActivityRecord) -> String {
        switch event.phase {
        case .observed: "正在读取窗口结构"
        case .confirmationRequested: "执行前等待 App 二次确认"
        case .confirmationRejected: "操作未执行"
        case .actionStarted: "正在执行 \(event.action ?? "操作")"
        case .actionFinished: "已重新读取界面结果"
        }
    }
}

private struct WindowPreviewView: View {
    let target: ControlledTarget
    let image: NSImage?
    let error: String?

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                RoundedRectangle(cornerRadius: 10).fill(Color.black.opacity(0.88))
                if let image {
                    let imageSize = image.size
                    let scale = min(proxy.size.width / max(1, imageSize.width), proxy.size.height / max(1, imageSize.height))
                    let fitted = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: fitted.width, height: fitted.height)
                    if let pointer = target.pointer {
                        let localX = pointer.x - target.windowBounds.origin.x
                        let localY = pointer.y - target.windowBounds.origin.y
                        let px = (proxy.size.width - fitted.width) / 2 + localX / max(1, target.windowBounds.size.width) * fitted.width
                        let py = (proxy.size.height - fitted.height) / 2 + localY / max(1, target.windowBounds.size.height) * fitted.height
                        CursorMarker().position(x: px, y: py)
                    }
                } else if let error {
                    ContentUnavailableView("暂时无法读取画面", systemImage: "rectangle.slash", description: Text(error))
                        .foregroundStyle(.white)
                } else {
                    VStack(spacing: 10) {
                        ProgressView().controlSize(.large)
                        Text("正在获取窗口画面…").foregroundStyle(.white.opacity(0.72))
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
}

private struct CursorMarker: View {
    var body: some View {
        ZStack {
            Circle().fill(Color.cyan.opacity(0.12)).frame(width: 88, height: 88).blur(radius: 2)
            Circle().fill(Color.blue.opacity(0.20)).frame(width: 62, height: 62)
            Circle().stroke(Color.cyan.opacity(0.9), lineWidth: 2).frame(width: 62, height: 62)
            Image(systemName: "cursorarrow").font(.system(size: 24, weight: .semibold)).foregroundStyle(.white)
        }
    }
}

private struct PermissionSettingsView: View {
    @ObservedObject var model: BridgeSettingsModel

    var body: some View {
        PageContainer(title: "系统权限", subtitle: "Bridge 只会申请完成应用读取和操作所需的系统权限。") {
            SettingsCard {
                VStack(spacing: 16) {
                    StatusRow(symbol: "accessibility", title: "辅助功能", detail: "控制应用控件", ready: model.permissions.accessibilityTrusted)
                    Divider()
                    StatusRow(symbol: "rectangle.on.rectangle", title: "屏幕录制", detail: "读取目标窗口画面，不录制系统音频", ready: model.permissions.screenCaptureAllowed == true)
                }
            }
            HStack {
                Button("重新检查") { model.refresh() }
                Button("打开系统设置") {
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
                }
                Spacer()
            }
        }
    }
}

private struct ConnectionSettingsView: View {
    @ObservedObject var model: BridgeSettingsModel
    @State private var copied = false

    var body: some View {
        PageContainer(title: "连接", subtitle: "让 Cursor、WorkBuddy 或其他 Agent 连接本机 Bridge。") {
            SettingsCard {
                VStack(alignment: .leading, spacing: 14) {
                    HStack { Text("本地 MCP 地址").font(.headline); Spacer(); Text("已启用").foregroundStyle(.green) }
                    Text(model.connectionURL).font(.system(.body, design: .monospaced)).textSelection(.enabled)
                    Text("仅监听这台 Mac，不接受局域网或公网访问。")
                        .font(.caption).foregroundStyle(.secondary)
                    Button(copied ? "已复制" : "复制连接配置") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(model.connectionURL, forType: .string)
                        copied = true
                    }
                }
            }
            SettingsCard {
                VStack(alignment: .leading, spacing: 10) {
                    Text("已验证客户端").font(.headline)
                    Label("Cursor · 本机程序连接", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                    Label("WorkBuddy · 本地地址连接", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                }
            }
        }
    }
}

private struct AppAccessSettingsView: View {
    @ObservedObject var model: BridgeSettingsModel

    var body: some View {
        PageContainer(title: "应用访问", subtitle: "控制 Bridge 可以读取和操作哪些本机应用。") {
            SettingsCard {
                Toggle("默认允许新应用", isOn: Binding(
                    get: { model.accessPolicy.defaultAllow },
                    set: { model.setDefaultAppAccess($0) }
                ))
                Text("关闭后，新应用需要先在这里明确允许。系统应用和密码输入始终受额外保护。")
                    .font(.caption).foregroundStyle(.secondary).padding(.top, 6)
            }
            SettingsCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("正在运行的应用").font(.headline)
                    ForEach(model.runningApps.filter { $0.appID != "com.juln.ui-bridge" }.prefix(18), id: \.pid) { app in
                        HStack(spacing: 12) {
                            AppIconView(pid: app.pid, size: 28)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(app.name).fontWeight(.medium)
                                Text(app.appID).font(.caption2).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Picker("访问", selection: Binding(
                                get: { accessChoice(app.appID) },
                                set: { setAccessChoice($0, appID: app.appID) }
                            )) {
                                Text("跟随默认").tag(0)
                                Text("允许").tag(1)
                                Text("阻止").tag(2)
                            }
                            .labelsHidden().frame(width: 118)
                        }
                        if app.pid != model.runningApps.last?.pid { Divider() }
                    }
                }
            }
        }
    }

    private func accessChoice(_ appID: String) -> Int {
        guard let value = model.accessPolicy.rules[appID] else { return 0 }
        return value ? 1 : 2
    }

    private func setAccessChoice(_ choice: Int, appID: String) {
        model.setAppAccess(choice == 0 ? nil : choice == 1, appID: appID)
    }
}

private struct SafetySettingsView: View {
    @ObservedObject var model: BridgeSettingsModel
    @AppStorage("safety.confirmDangerousActions") private var confirmDangerousActions = true

    var body: some View {
        PageContainer(title: "操作安全", subtitle: "危险操作必须在执行前清楚展示目标、动作和影响。") {
            SettingsCard {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("危险操作需要 App 内二次确认", isOn: $confirmDangerousActions).disabled(true)
                    Label("删除、购买和权限变更始终需要二次确认，不能关闭。", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                    Text("拒绝、关闭弹窗或等待超时都会取消操作。确认只对弹窗中这一项具体操作有效。")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            SettingsCard {
                if let request = model.pendingDangerousRequest {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("等待确认：\(request.category.displayName)", systemImage: "exclamationmark.octagon.fill")
                            .font(.headline).foregroundStyle(.red)
                        LabeledContent("目标应用", value: request.appName)
                        LabeledContent("具体动作", value: request.action)
                        LabeledContent("目标", value: request.target)
                        LabeledContent("可能影响", value: request.impact)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("当前没有等待确认的操作").font(.headline)
                        Text("出现危险操作时，本页和系统弹窗会同时显示。")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

private struct DiagnosticsSettingsView: View {
    @ObservedObject var model: BridgeSettingsModel

    var body: some View {
        PageContainer(title: "调试与诊断", subtitle: "检查服务状态，不保存应用截图或正文。") {
            HStack(spacing: 14) {
                diagnosticMetric(
                    title: "本地服务",
                    value: model.serviceReady ? "正常" : "异常",
                    symbol: "server.rack",
                    color: model.serviceReady ? .green : .orange
                )
                diagnosticMetric(
                    title: "系统权限",
                    value: "\(permissionCount)/2",
                    symbol: "checkmark.shield.fill",
                    color: permissionCount == 2 ? .green : .orange
                )
                diagnosticMetric(
                    title: "最近客户端",
                    value: "\(recentClients.count)",
                    symbol: "cable.connector.horizontal",
                    color: .blue
                )
                diagnosticMetric(
                    title: "活动画面",
                    value: "\(model.session.frames.count)/\(model.session.targets.count)",
                    symbol: "rectangle.on.rectangle.angled",
                    color: model.session.errors.isEmpty ? .blue : .orange
                )
            }

            SettingsCard {
                VStack(spacing: 16) {
                    StatusRow(symbol: "server.rack", title: "本地服务", detail: "127.0.0.1:8765 · \(model.serviceDetail)", ready: model.serviceReady)
                    Divider()
                    StatusRow(symbol: "accessibility", title: "辅助功能", detail: "读取控件和执行操作", ready: model.permissions.accessibilityTrusted)
                    Divider()
                    StatusRow(symbol: "rectangle.on.rectangle", title: "屏幕录制", detail: "读取目标窗口画面", ready: model.permissions.screenCaptureAllowed == true)
                }
            }

            HStack(alignment: .top, spacing: 14) {
                SettingsCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("客户端活动").font(.headline)
                        if recentClients.isEmpty {
                            Label("最近 90 秒没有客户端活动", systemImage: "clock")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(recentClients, id: \.self) { client in
                                HStack {
                                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                                    Text(client).fontWeight(.medium)
                                    Spacer()
                                    Text("已识别").font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                        Divider()
                        LabeledContent("最近事件", value: "\(model.recentEvents.count) 条")
                    }
                }

                SettingsCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("实时画面").font(.headline)
                        LabeledContent("当前状态", value: model.session.status)
                        LabeledContent("活动窗口", value: "\(model.session.targets.count)")
                        LabeledContent("已连接画面", value: "\(model.session.frames.count)")
                        LabeledContent("画面错误", value: "\(model.session.errors.count)")
                    }
                }
            }

            SettingsCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("问题汇总").font(.headline)
                        Spacer()
                        Text(model.lastRefreshed, style: .time).font(.caption).foregroundStyle(.secondary)
                    }
                    if issues.isEmpty {
                        Label("未发现需要处理的问题", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else {
                        ForEach(issues, id: \.self) { issue in
                            Label(issue, systemImage: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                        }
                    }
                }
            }

            SettingsCard {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "hand.raised.fill").foregroundStyle(.blue).font(.title3)
                    VStack(alignment: .leading, spacing: 5) {
                        Text("脱敏诊断").font(.headline)
                        Text("复制和导出的内容只包含状态、数量和阶段，不包含截图、应用名称、窗口编号、界面正文或连接令牌。")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }

            HStack {
                Button("刷新诊断") { model.refresh() }
                Button("复制排错信息") { model.copyDiagnosticSummary() }
                Button("导出诊断报告…") { model.exportDiagnosticReport() }
                if let feedback = model.diagnosticsFeedback {
                    Label(feedback, systemImage: feedback.contains("失败") ? "xmark.circle.fill" : "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(feedback.contains("失败") ? .red : .green)
                }
                Spacer()
            }
        }
    }

    private var permissionCount: Int {
        (model.permissions.accessibilityTrusted ? 1 : 0) + (model.permissions.screenCaptureAllowed == true ? 1 : 0)
    }

    private var recentClients: [String] {
        Array(Set(model.recentEvents.compactMap(\.source))).sorted()
    }

    private var issues: [String] {
        var result: [String] = []
        if !model.serviceReady { result.append("本地服务无法连接") }
        if !model.permissions.accessibilityTrusted { result.append("辅助功能未授权") }
        if model.permissions.screenCaptureAllowed != true { result.append("屏幕录制未授权") }
        if !model.session.errors.isEmpty { result.append("有 \(model.session.errors.count) 个窗口画面读取失败") }
        return result
    }

    private func diagnosticMetric(title: String, value: String, symbol: String, color: Color) -> some View {
        SettingsCard {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: symbol).font(.title2).foregroundStyle(color)
                Text(value).font(.title3.bold())
                Text(title).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

struct AppIconView: View {
    let pid: Int32
    let size: CGFloat

    var body: some View {
        Image(nsImage: NSRunningApplication(processIdentifier: pid)?.icon ?? NSImage(systemSymbolName: "app", accessibilityDescription: nil)!)
            .resizable().aspectRatio(contentMode: .fit).frame(width: size, height: size)
    }
}
