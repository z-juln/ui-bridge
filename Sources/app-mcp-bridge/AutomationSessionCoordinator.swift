import AppKit
import Foundation

@MainActor
final class AutomationSessionCoordinator: ObservableObject {
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
        guard let executable = Bundle.main.executableURL else {
            errors[target.pid] = "无法找到画面服务"
            return
        }
        let capture = WindowPreviewClient(
            executable: executable,
            windowID: target.windowID,
            onFrame: { [weak self] data in
                Task { @MainActor [weak self] in
                    guard let self, self.viewerActive,
                          self.streams[target.pid]?.windowID == target.windowID,
                          let image = NSImage(data: data) else { return }
                    self.frames[target.pid] = image
                    self.errors[target.pid] = nil
                    self.status = "实时画面已连接"
                }
            },
            onStopped: { [weak self] message in
                Task { @MainActor [weak self] in
                    guard let self, self.viewerActive,
                          self.streams[target.pid]?.windowID == target.windowID else { return }
                    self.errors[target.pid] = message
                    self.status = "部分窗口无法显示"
                }
            }
        )
        streams[target.pid] = ActiveStream(windowID: target.windowID, capture: capture)
        do {
            try capture.start()
        } catch {
            errors[target.pid] = error.localizedDescription
            status = "部分窗口无法显示"
        }
    }

    private func stopAllStreams() {
        let captures = streams.values.map(\.capture)
        streams.removeAll()
        frames.removeAll()
        errors.removeAll()
        captures.forEach { $0.stop() }
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
        frames.forEach(onFrame)
    }
}
