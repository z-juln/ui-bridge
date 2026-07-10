import ApplicationServices
import Foundation
import UIBridgeProtocol

public final class AccessibilityActionExecutor: @unchecked Sendable {
    private let treeReader: AccessibilityTreeReader

    public init(treeReader: AccessibilityTreeReader) {
        self.treeReader = treeReader
    }

    public func execute(_ request: ActionRequest) throws -> ActionResult {
        guard request.delivery == .background else {
            return ActionResult(
                actionID: UUID().uuidString,
                status: .foregroundRequired,
                deliveryUsed: "none",
                focusChanged: false,
                evidence: ActionEvidence(condition: "explicit_foreground_consent_required")
            )
        }

        guard case let .element(handle) = request.target else {
            throw BridgeError(
                code: .unsupported,
                message: "Coordinate actions require a window-aware event executor.",
                suggestedAction: "Use an accessibility element or the coordinate executor."
            )
        }
        guard handle.hasPrefix("\(request.snapshotID):") else {
            throw BridgeError(code: .snapshotStale, message: "Element handle does not belong to the requested snapshot.", retryable: true)
        }
        guard let element = treeReader.element(forHandle: handle) else {
            throw BridgeError(code: .elementNotFound, message: "Element handle is stale or unknown.", retryable: true)
        }

        let effect: AXError
        switch request.action {
        case .press:
            effect = AXUIElementPerformAction(element, kAXPressAction as CFString)
        case .select:
            effect = AXUIElementSetAttributeValue(element, kAXSelectedAttribute as CFString, kCFBooleanTrue)
        case .setValue, .typeText:
            guard let text = request.text else {
                throw BridgeError(code: .invalidRequest, message: "Text is required for \(request.action.rawValue).")
            }
            effect = AXUIElementSetAttributeValue(element, kAXValueAttribute as CFString, text as CFString)
        case .showMenu:
            effect = AXUIElementPerformAction(element, kAXShowMenuAction as CFString)
        case .pressKey, .scroll, .coordinateClick:
            throw BridgeError(
                code: .unsupported,
                message: "\(request.action.rawValue) is not an accessibility-only action.",
                suggestedAction: "Use the process event executor."
            )
        }

        guard effect == .success else {
            throw BridgeError(
                code: effect == .notImplemented ? .unsupported : .internalFailure,
                message: "Accessibility action failed with AXError \(effect.rawValue).",
                retryable: effect == .cannotComplete
            )
        }

        return ActionResult(
            actionID: UUID().uuidString,
            status: request.verification == nil ? .ambiguous : .notObserved,
            deliveryUsed: "accessibility",
            focusChanged: false,
            evidence: ActionEvidence(condition: "action_delivered_verification_pending")
        )
    }
}
