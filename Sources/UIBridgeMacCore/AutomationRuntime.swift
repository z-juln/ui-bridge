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
    private var stopped = false
    private let activitySource: String

    public init(activitySource: String = "本地调用") {
        self.activitySource = activitySource
    }

    public func createSnapshot(
        pid: Int32,
        windowID: UInt32,
        includeScreenshot: Bool = false,
        maxElements: Int = 1_000,
        maxDepth: Int = 20,
        activitySource sourceOverride: String? = nil
    ) async throws -> Snapshot {
        guard let app = AppDiscovery.listRunningApplications().first(where: { $0.pid == pid }) else {
            throw BridgeError(code: .appNotFound, message: "No running application has pid \(pid).", retryable: true)
        }
        guard AppAccessPolicyStore.load().allows(appID: app.appID) else {
            throw BridgeError(
                code: .invalidRequest,
                message: "Access to \(app.name) is blocked by the App MCP Bridge application policy.",
                suggestedAction: "Allow this application in App MCP Bridge → 应用访问."
            )
        }
        guard let window = WindowDiscovery.listWindows(pid: pid).first(where: { $0.windowID == windowID }) else {
            throw BridgeError(code: .elementNotFound, message: "Window \(windowID) does not belong to pid \(pid).", retryable: true)
        }

        let snapshotID = UUID().uuidString
        let read = try treeReader.readWindow(
            pid: pid,
            snapshotID: snapshotID,
            windowBounds: window.bounds,
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
        AutomationActivityCenter.publish(
            phase: .observed,
            snapshot: snapshot,
            source: sourceOverride ?? activitySource
        )
        return snapshot
    }

    public func screenshotData(handle: String) -> Data? {
        lock.withLock { screenshots[handle] }
    }

    public func snapshot(id: String) throws -> Snapshot {
        guard let context = lock.withLock({ contexts[id] }), context.snapshot.expiresAt > Date() else {
            discard(snapshotID: id)
            throw BridgeError(code: .snapshotStale, message: "Snapshot is expired or unknown.", retryable: true)
        }
        return context.snapshot
    }

    public func findElements(
        snapshotID: String,
        role: String? = nil,
        text: String? = nil,
        enabled: Bool? = nil,
        settable: Bool? = nil,
        limit: Int = 50
    ) throws -> [ElementDescriptor] {
        let snapshot = try snapshot(id: snapshotID)
        return Array(snapshot.elements.lazy.filter { element in
            if let role, element.role.caseInsensitiveCompare(role) != .orderedSame { return false }
            if let enabled, element.state.isEnabled != enabled { return false }
            if let settable, element.state.isSettable != settable { return false }
            if let text {
                let matches = element.label?.localizedCaseInsensitiveContains(text) == true
                    || element.value?.localizedCaseInsensitiveContains(text) == true
                if !matches { return false }
            }
            return true
        }.prefix(max(1, min(limit, 200))))
    }

    public func checkPlan(
        snapshotID: String,
        elementHandle: String?,
        action: ActionKind,
        coordinate: UIBPoint? = nil,
        delivery: DeliveryPreference = .background,
        highImpact: Bool = false,
        confirmed: Bool = false,
        foregroundApproved: Bool = false
    ) throws -> PlanCheckResult {
        let snapshot = try snapshot(id: snapshotID)

        if highImpact && !confirmed {
            return PlanCheckResult(
                snapshotID: snapshotID,
                readiness: .needsConfirmation,
                reason: "The proposed action is high impact and has not been explicitly confirmed.",
                recommendations: ["Ask for confirmation immediately before executing this exact action."]
            )
        }
        if delivery == .foreground && !foregroundApproved {
            return PlanCheckResult(
                snapshotID: snapshotID,
                readiness: .needsForegroundApproval,
                reason: "The proposed action would bring the target app forward.",
                recommendations: ["Explain the focus change and obtain approval before execution."]
            )
        }

        if action == .coordinateClick {
            guard snapshot.screenshot != nil else {
                return PlanCheckResult(
                    snapshotID: snapshotID,
                    readiness: .needsScreenshot,
                    reason: "A coordinate click must be grounded in a screenshot from the same snapshot.",
                    recommendations: ["Create a new snapshot with include_screenshot=true, inspect it, then derive fresh coordinates."]
                )
            }
            guard let coordinate,
                  coordinate.x >= 0, coordinate.y >= 0,
                  coordinate.x <= snapshot.windowBounds.size.width,
                  coordinate.y <= snapshot.windowBounds.size.height else {
                return PlanCheckResult(
                    snapshotID: snapshotID,
                    readiness: .rejected,
                    reason: "The coordinate is missing or outside the current window.",
                    recommendations: ["Choose a point inside the current window screenshot."]
                )
            }
            return PlanCheckResult(
                snapshotID: snapshotID,
                readiness: .ready,
                reason: "The coordinate is inside a screenshot-backed current window.",
                recommendations: ["Execute once with a concrete verification condition; refresh instead of repeating if it is not observed."]
            )
        }

        guard let elementHandle,
              elementHandle.hasPrefix("\(snapshotID):"),
              let element = snapshot.elements.first(where: { $0.handle == elementHandle }) else {
            return PlanCheckResult(
                snapshotID: snapshotID,
                readiness: .rejected,
                reason: "The target element is missing or does not belong to the current snapshot.",
                recommendations: ["Use element_find on this snapshot and choose one unambiguous current handle."]
            )
        }

        if (action == .setValue || action == .typeText) && !element.state.isSettable {
            return PlanCheckResult(
                snapshotID: snapshotID,
                readiness: .rejected,
                reason: "The selected element is not settable.",
                target: element,
                recommendations: ["Find a current editable element with settable=true."]
            )
        }

        return PlanCheckResult(
            snapshotID: snapshotID,
            readiness: .ready,
            reason: "The target belongs to the current snapshot and satisfies the action prerequisites.",
            target: element,
            recommendations: ["Execute once with a concrete verification condition; use the returned snapshot for the next step."]
        )
    }

    public func execute(
        _ request: ActionRequest,
        highImpact: Bool,
        confirmed: Bool,
        foregroundApproved: Bool = false,
        riskCategory: DangerousActionCategory = .other,
        confirmationSummary: String? = nil,
        activitySource sourceOverride: String? = nil
    ) async throws -> ActionResult {
        guard !lock.withLock({ stopped }) else {
            throw BridgeError(code: .invalidRequest, message: "This automation session was stopped. Start a new MCP connection or service session to resume.")
        }
        if highImpact && !confirmed {
            return ActionResult(
                actionID: UUID().uuidString,
                status: .confirmationRequired,
                deliveryUsed: "none",
                focusChanged: false,
                evidence: ActionEvidence(condition: "explicit_user_confirmation_required")
            )
        }
        if highImpact {
            guard let context = lock.withLock({ contexts[request.snapshotID] }) else {
                throw BridgeError(code: .snapshotStale, message: "Snapshot is expired or unknown.", retryable: true)
            }
            let appName = AppDiscovery.listRunningApplications().first(where: { $0.pid == context.snapshot.pid })?.name
                ?? context.snapshot.appID
            let targetDescription: String = switch request.target {
            case .element(let handle): "界面控件 \(handle.suffix(12))"
            case .coordinate(let point): "窗口位置 (\(Int(point.x)), \(Int(point.y)))"
            }
            AutomationActivityCenter.publish(
                phase: .confirmationRequested,
                snapshot: context.snapshot,
                source: sourceOverride ?? activitySource,
                action: confirmationSummary ?? request.action.rawValue,
                risk: riskCategory.rawValue
            )
            let approved = await DangerousActionConfirmationCenter.requestApproval(
                category: riskCategory,
                appName: appName,
                action: confirmationSummary ?? request.action.rawValue,
                target: targetDescription,
                impact: riskCategory == .other ? "该操作可能产生难以撤销的结果" : "将执行一次\(riskCategory.displayName)操作"
            )
            guard approved else {
                AutomationActivityCenter.publish(
                    phase: .confirmationRejected,
                    snapshot: context.snapshot,
                    source: sourceOverride ?? activitySource,
                    action: confirmationSummary ?? request.action.rawValue,
                    risk: riskCategory.rawValue
                )
                return ActionResult(
                    actionID: UUID().uuidString,
                    status: .confirmationRequired,
                    deliveryUsed: "none",
                    focusChanged: false,
                    evidence: ActionEvidence(condition: "app_second_confirmation_required_or_rejected")
                )
            }
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

        let activityPointer = pointerLocation(for: request, in: context.snapshot)
        AutomationActivityCenter.publish(
            phase: .actionStarted,
            snapshot: context.snapshot,
            pointer: activityPointer,
            source: sourceOverride ?? activitySource,
            action: request.action.rawValue,
            risk: highImpact ? riskCategory.rawValue : nil
        )
        defer {
            AutomationActivityCenter.publish(
                phase: .actionFinished,
                snapshot: context.snapshot,
                pointer: activityPointer,
                source: sourceOverride ?? activitySource,
                action: request.action.rawValue,
                risk: highImpact ? riskCategory.rawValue : nil
            )
        }
        let delivered: ActionResult
        switch request.action {
        case .pressKey, .scroll, .coordinateClick:
            delivered = try ProcessEventExecutor.execute(request, snapshot: context.snapshot, foregroundApproved: foregroundApproved)
        default:
            delivered = try AccessibilityActionExecutor(treeReader: treeReader).execute(request)
        }
        guard delivered.status != .foregroundRequired else { return delivered }

        let after = try await createSnapshot(
            pid: context.snapshot.pid,
            windowID: context.snapshot.windowID,
            includeScreenshot: context.includedScreenshot,
            maxElements: context.maxElements,
            maxDepth: context.maxDepth,
            activitySource: sourceOverride ?? activitySource
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

    public func emergencyStop() {
        let snapshotIDs = lock.withLock { () -> [String] in
            stopped = true
            let ids = Array(contexts.keys)
            contexts.removeAll()
            screenshots.removeAll()
            return ids
        }
        for id in snapshotIDs { treeReader.discard(snapshotID: id) }
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

    private func pointerLocation(for request: ActionRequest, in snapshot: Snapshot) -> UIBPoint? {
        switch request.target {
        case let .coordinate(point):
            return UIBPoint(
                x: snapshot.windowBounds.origin.x + point.x,
                y: snapshot.windowBounds.origin.y + point.y
            )
        case let .element(handle):
            guard let frame = snapshot.elements.first(where: { $0.handle == handle })?.frameInWindow else {
                return nil
            }
            return UIBPoint(
                x: snapshot.windowBounds.origin.x + frame.origin.x + frame.size.width / 2,
                y: snapshot.windowBounds.origin.y + frame.origin.y + frame.size.height / 2
            )
        }
    }
}
