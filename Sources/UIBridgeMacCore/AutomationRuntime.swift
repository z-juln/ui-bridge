import Foundation
import UIBridgeProtocol

public final class AutomationRuntime: @unchecked Sendable {
    private struct SnapshotContext {
        let snapshot: Snapshot
        let maxElements: Int
        let maxDepth: Int
        let includedScreenshot: Bool
    }

    private let treeReader = AccessibilityTreeReader()
    private let lock = NSLock()
    private var contexts: [String: SnapshotContext] = [:]
    private var screenshots: [String: Data] = [:]

    public init() {}

    public func createSnapshot(
        pid: Int32,
        windowID: UInt32,
        includeScreenshot: Bool = false,
        maxElements: Int = 1_000,
        maxDepth: Int = 20
    ) async throws -> Snapshot {
        guard let app = AppDiscovery.listRunningApplications().first(where: { $0.pid == pid }) else {
            throw BridgeError(code: .appNotFound, message: "No running application has pid \(pid).", retryable: true)
        }
        guard let window = WindowDiscovery.listWindows(pid: pid).first(where: { $0.windowID == windowID }) else {
            throw BridgeError(code: .elementNotFound, message: "Window \(windowID) does not belong to pid \(pid).", retryable: true)
        }

        let snapshotID = UUID().uuidString
        let read = try treeReader.readApplication(
            pid: pid,
            snapshotID: snapshotID,
            options: AccessibilityReadOptions(maxElements: maxElements, maxDepth: maxDepth)
        )
        let captured: CapturedWindow? = if includeScreenshot {
            try await WindowCapture.capture(windowID: windowID, handle: "shot-\(snapshotID)")
        } else {
            nil
        }
        let now = Date()
        let snapshot = Snapshot(
            snapshotID: snapshotID,
            appID: app.appID,
            pid: pid,
            windowID: windowID,
            createdAt: now,
            expiresAt: now.addingTimeInterval(60),
            treeQuality: read.treeQuality,
            windowBounds: window.bounds,
            screenshot: captured?.descriptor,
            elements: read.elements
        )
        lock.withLock {
            removeExpiredLocked(now: now)
            contexts[snapshotID] = SnapshotContext(
                snapshot: snapshot,
                maxElements: maxElements,
                maxDepth: maxDepth,
                includedScreenshot: includeScreenshot
            )
            if let captured { screenshots[captured.descriptor.handle] = captured.pngData }
        }
        return snapshot
    }

    public func screenshotData(handle: String) -> Data? {
        lock.withLock { screenshots[handle] }
    }

    public func execute(_ request: ActionRequest, highImpact: Bool, confirmed: Bool) async throws -> ActionResult {
        if highImpact && !confirmed {
            return ActionResult(
                actionID: UUID().uuidString,
                status: .confirmationRequired,
                deliveryUsed: "none",
                focusChanged: false,
                evidence: ActionEvidence(condition: "explicit_user_confirmation_required")
            )
        }
        guard request.verification != nil else {
            throw BridgeError(code: .invalidRequest, message: "Every action must include a verification expectation.")
        }
        guard let context = lock.withLock({ contexts[request.snapshotID] }) else {
            throw BridgeError(code: .snapshotStale, message: "Snapshot is expired or unknown.", retryable: true)
        }
        guard context.snapshot.expiresAt > Date() else {
            discard(snapshotID: request.snapshotID)
            throw BridgeError(code: .snapshotStale, message: "Snapshot expired before the action.", retryable: true)
        }

        let delivered = try AccessibilityActionExecutor(treeReader: treeReader).execute(request)
        guard delivered.status != .foregroundRequired else { return delivered }

        let after = try await createSnapshot(
            pid: context.snapshot.pid,
            windowID: context.snapshot.windowID,
            includeScreenshot: context.includedScreenshot,
            maxElements: context.maxElements,
            maxDepth: context.maxDepth
        )
        let evidence = request.verification.flatMap {
            VerificationEngine.verify(expectation: $0, before: context.snapshot, after: after)
        }
        return ActionResult(
            actionID: delivered.actionID,
            status: evidence == nil ? .notObserved : .confirmed,
            deliveryUsed: delivered.deliveryUsed,
            focusChanged: delivered.focusChanged,
            newSnapshotID: after.snapshotID,
            evidence: evidence ?? ActionEvidence(condition: "verification_not_observed")
        )
    }

    private func discard(snapshotID: String) {
        _ = lock.withLock { contexts.removeValue(forKey: snapshotID) }
        treeReader.discard(snapshotID: snapshotID)
    }

    private func removeExpiredLocked(now: Date) {
        let expired = contexts.values.filter { $0.snapshot.expiresAt <= now }
        for context in expired {
            contexts.removeValue(forKey: context.snapshot.snapshotID)
            if let handle = context.snapshot.screenshot?.handle { screenshots.removeValue(forKey: handle) }
            treeReader.discard(snapshotID: context.snapshot.snapshotID)
        }
    }
}
