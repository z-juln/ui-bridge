import Foundation
import UIBridgeProtocol

public enum VerificationEngine {
    public static func verify(
        expectation: VerificationExpectation,
        before: Snapshot,
        after: Snapshot
    ) -> ActionEvidence? {
        switch expectation.kind {
        case .elementPresent:
            guard let value = expectation.value else { return nil }
            let found = after.elements.contains { matches($0, value: value) }
            return found ? ActionEvidence(condition: expectation.kind.rawValue, observed: value) : nil
        case .elementAbsent:
            guard let value = expectation.value else { return nil }
            let found = after.elements.contains { matches($0, value: value) }
            return found ? nil : ActionEvidence(condition: expectation.kind.rawValue, observed: value)
        case .elementValueContains:
            guard let value = expectation.value else { return nil }
            let observed = after.elements.compactMap(\.value).first { $0.localizedCaseInsensitiveContains(value) }
            return observed.map { ActionEvidence(condition: expectation.kind.rawValue, observed: $0) }
        case .windowTitleContains:
            return nil
        case .screenshotChanged:
            guard let beforeHandle = before.screenshot?.handle, let afterHandle = after.screenshot?.handle else { return nil }
            return beforeHandle == afterHandle ? nil : ActionEvidence(condition: expectation.kind.rawValue, observed: afterHandle)
        }
    }

    private static func matches(_ element: ElementDescriptor, value: String) -> Bool {
        element.label?.localizedCaseInsensitiveContains(value) == true ||
            element.value?.localizedCaseInsensitiveContains(value) == true
    }
}
