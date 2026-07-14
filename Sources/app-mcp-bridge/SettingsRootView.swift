import AppKit
import SwiftUI

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
                    Text("App MCP Bridge").font(.headline)
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
                                .frame(minHeight: 330)
                        }
                    }
                }

                HStack(alignment: .top, spacing: 14) {
                    SettingsCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("操控映射").font(.headline)
                            mappingRow(symbol: "sparkles", title: "来源", value: selectedTarget?.source ?? "本地 MCP")
                            mappingRow(symbol: "point.3.connected.trianglepath.dotted", title: "经过", value: "App MCP Bridge")
                            mappingRow(symbol: "app", title: "目标", value: selectedTarget?.name ?? "—")
                        }
                    }
                    SettingsCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("最近事件").font(.headline)
                            ForEach(Array(model.recentEvents.suffix(4).reversed()), id: \.eventID) { event in
                                HStack {
                                    Circle().fill(event.phase == .actionStarted ? .blue : .green).frame(width: 7, height: 7)
                                    Text(event.appName).lineLimit(1)
                                    Text(event.action ?? "读取界面").foregroundStyle(.secondary)
                                    Spacer()
                                    Text(event.createdAt, style: .time).foregroundStyle(.tertiary)
                                }
                                .font(.caption)
                            }
                        }
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

    private func mappingRow(symbol: String, title: String, value: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol).foregroundStyle(.blue).frame(width: 22)
            Text(title).foregroundStyle(.secondary)
            Spacer()
            Text(value).fontWeight(.medium)
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
                    ForEach(model.runningApps.filter { $0.appID != "com.juln.app-mcp-bridge" }.prefix(18), id: \.pid) { app in
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
            SettingsCard {
                VStack(spacing: 14) {
                    StatusRow(symbol: "server.rack", title: "本地服务", detail: "127.0.0.1:8765", ready: model.serviceReady)
                    Divider()
                    StatusRow(symbol: "network", title: "MCP 连接入口", detail: "/mcp", ready: true)
                    Divider()
                    HStack { Text("最近刷新"); Spacer(); Text(model.lastRefreshed, style: .time).foregroundStyle(.secondary) }
                }
            }
            HStack {
                Button("刷新诊断") { model.refresh() }
                Button("复制无内容诊断") {
                    let value = "服务：运行中\n辅助功能：\(model.permissions.accessibilityTrusted ? "正常" : "未授权")\n屏幕录制：\(model.permissions.screenCaptureAllowed == true ? "正常" : "未授权")\n活动应用数：\(model.activeTargets.count)"
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(value, forType: .string)
                }
                Spacer()
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
