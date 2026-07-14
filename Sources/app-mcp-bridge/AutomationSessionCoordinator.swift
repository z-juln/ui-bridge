import AppKit
import Foundation

@MainActor
final class AutomationSessionCoordinator: NSObject, ObservableObject {
    @Published private(set) var targets: [ControlledTarget] = []
    @Published private(set) var frames: [Int32: NSImage] = [:]
    @Published private(set) var errors: [Int32: String] = [:]
    @Published private(set) var status = "等待活动"

    private struct ActiveStream {
        let windowID: UInt32
        let capture: WindowPreviewClient
    }

    private var streams: [Int32: ActiveStream] = [:]
    private var viewerActive = false
    nonisolated private let pendingUpdates = PendingPreviewUpdates()

    func updateTargets(_ newTargets: [ControlledTarget]) {
        targets = Array(newTargets.prefix(6))
        reconcileStreams()
    }

    func setViewerActive(_ active: Bool) {
        guard viewerActive != active else { return }
        viewerActive = active
        reconcileStreams()
    }

    func clear() {
        targets = []
        stopAllStreams()
    }

    private func reconcileStreams() {
        guard viewerActive else {
            stopAllStreams()
            status = targets.isEmpty ? "等待活动" : "实时画面已暂停"
            return
        }

        let desired = Dictionary(uniqueKeysWithValues: targets.map { ($0.pid, $0) })
        for (pid, active) in streams where desired[pid]?.windowID != active.windowID {
            streams.removeValue(forKey: pid)
            active.capture.stop()
            frames[pid] = nil
            errors[pid] = nil
        }

        for target in targets where streams[target.pid] == nil {
            startStream(for: target)
        }

        if targets.isEmpty {
            status = "等待活动"
        } else if !frames.isEmpty {
            status = "实时画面已连接"
        } else {
            status = "正在连接 \(targets.count) 个窗口"
        }
    }

    private func startStream(for target: ControlledTarget) {
        PreviewDiagnosticCenter.record("coordinator_launch_requested", windowID: target.windowID)
        guard let executable = Bundle.main.executableURL else {
            errors[target.pid] = "无法找到画面服务"
            return
        }
        let capture = WindowPreviewClient(
            executable: executable,
            windowID: target.windowID,
            onFrame: { [weak self] data in
                PreviewDiagnosticCenter.record("coordinator_frame_received", windowID: target.windowID, detail: "bytes=\(data.count)")
                self?.enqueueFrame(data, for: target)
            },
            onStopped: { [weak self] message in
                self?.enqueueError(message, for: target)
            }
        )
        streams[target.pid] = ActiveStream(windowID: target.windowID, capture: capture)
        do {
            try capture.start()
            PreviewDiagnosticCenter.record("coordinator_process_started", windowID: target.windowID)
        } catch {
            errors[target.pid] = error.localizedDescription
            status = "部分窗口无法显示"
        }
    }

    nonisolated private func enqueueFrame(_ data: Data, for target: ControlledTarget) {
        pendingUpdates.setFrame(data, for: target)
        schedulePendingUpdate()
    }

    nonisolated private func enqueueError(_ message: String, for target: ControlledTarget) {
        pendingUpdates.setError(message, for: target)
        schedulePendingUpdate()
    }

    nonisolated private func schedulePendingUpdate() {
        performSelector(
            onMainThread: #selector(applyPendingUpdates),
            with: nil,
            waitUntilDone: false,
            modes: [RunLoop.Mode.common.rawValue]
        )
    }

    @objc private func applyPendingUpdates() {
        let updates = pendingUpdates.take()
        for update in updates {
            guard viewerActive,
                  streams[update.target.pid]?.windowID == update.target.windowID else { continue }
            switch update.value {
            case .frame(let data):
                guard let image = NSImage(data: data) else {
                    errors[update.target.pid] = "画面格式无效"
                    continue
                }
                frames[update.target.pid] = image
                errors[update.target.pid] = nil
                status = "实时画面已连接"
                PreviewDiagnosticCenter.record("coordinator_frame_applied", windowID: update.target.windowID)
            case .error(let message):
                errors[update.target.pid] = message
                status = "部分窗口无法显示"
            }
        }
    }

    private func stopAllStreams() {
        let captures = streams.values.map(\.capture)
        streams.removeAll()
        frames.removeAll()
        errors.removeAll()
        captures.forEach { $0.stop() }
        if !captures.isEmpty {
            PreviewDiagnosticCenter.record("coordinator_streams_stopped", windowID: 0, detail: "count=\(captures.count)")
        }
    }
}

private struct PendingPreviewUpdate: Sendable {
    enum Value: Sendable {
        case frame(Data)
        case error(String)
    }

    let target: ControlledTarget
    let value: Value
}

private final class PendingPreviewUpdates: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [Int32: PendingPreviewUpdate] = [:]

    func setFrame(_ data: Data, for target: ControlledTarget) {
        lock.withLock {
            values[target.pid] = PendingPreviewUpdate(target: target, value: .frame(data))
        }
    }

    func setError(_ message: String, for target: ControlledTarget) {
        lock.withLock {
            values[target.pid] = PendingPreviewUpdate(target: target, value: .error(message))
        }
    }

    func take() -> [PendingPreviewUpdate] {
        lock.withLock {
            defer { values.removeAll() }
            return Array(values.values)
        }
    }
}

private final class WindowPreviewClient: @unchecked Sendable {
    private let executable: URL
    private let windowID: UInt32
    private let onFrame: @Sendable (Data) -> Void
    private let onStopped: @Sendable (String) -> Void
    private let lock = NSLock()
    private var buffer = Data()
    private var process: Process?
    private var stopping = false

    init(
        executable: URL,
        windowID: UInt32,
        onFrame: @escaping @Sendable (Data) -> Void,
        onStopped: @escaping @Sendable (String) -> Void
    ) {
        self.executable = executable
        self.windowID = windowID
        self.onFrame = onFrame
        self.onStopped = onStopped
    }

    func start() throws {
        let process = Process()
        let output = Pipe()
        let errors = Pipe()
        process.executableURL = executable
        process.arguments = ["preview-stream", String(windowID)]
        process.standardOutput = output
        process.standardError = errors
        output.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            self?.consume(data)
        }
        process.terminationHandler = { [weak self] process in
            guard let self else { return }
            output.fileHandleForReading.readabilityHandler = nil
            let errorData = errors.fileHandleForReading.readDataToEndOfFile()
            let message = String(decoding: errorData, as: UTF8.self)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let wasStopping = self.lock.withLock { self.stopping }
            if !wasStopping {
                self.onStopped(message.isEmpty ? "画面服务已停止（\(process.terminationStatus)）" : message)
            }
        }
        self.process = process
        try process.run()
        PreviewDiagnosticCenter.record(
            "client_process_running",
            windowID: windowID,
            detail: "child_pid=\(process.processIdentifier)"
        )
    }

    func stop() {
        let process = lock.withLock { () -> Process? in
            stopping = true
            return self.process
        }
        if process?.isRunning == true {
            process?.terminate()
        }
    }

    private func consume(_ data: Data) {
        PreviewDiagnosticCenter.record("client_bytes_received", windowID: windowID, detail: "bytes=\(data.count)")
        let frames: [Data] = lock.withLock {
            buffer.append(data)
            var decoded: [Data] = []
            while buffer.count >= 4 {
                let length = buffer.prefix(4).reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
                guard length > 0, length <= 20_000_000 else {
                    buffer.removeAll()
                    break
                }
                let total = 4 + Int(length)
                guard buffer.count >= total else { break }
                decoded.append(buffer.subdata(in: 4..<total))
                buffer.removeSubrange(0..<total)
            }
            return decoded
        }
        if let first = frames.first {
            PreviewDiagnosticCenter.record("client_frame_decoded", windowID: windowID, detail: "bytes=\(first.count)")
        }
        frames.forEach(onFrame)
    }
}
