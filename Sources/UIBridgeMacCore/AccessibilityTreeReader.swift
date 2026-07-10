import ApplicationServices
import Foundation
import UIBridgeProtocol

public struct AccessibilityReadOptions: Sendable {
    public var maxElements: Int
    public var maxDepth: Int
    public var timeout: TimeInterval

    public init(maxElements: Int = 2_000, maxDepth: Int = 30, timeout: TimeInterval = 1) {
        self.maxElements = max(1, maxElements)
        self.maxDepth = max(1, maxDepth)
        self.timeout = max(0.1, timeout)
    }
}

public struct AccessibilityReadResult: Sendable {
    public let treeQuality: TreeQuality
    public let elements: [ElementDescriptor]
    public let truncated: Bool

    public init(treeQuality: TreeQuality, elements: [ElementDescriptor], truncated: Bool) {
        self.treeQuality = treeQuality
        self.elements = elements
        self.truncated = truncated
    }
}

public final class AccessibilityTreeReader: @unchecked Sendable {
    private static let relationshipAttributes = [
        "AXChildren",
        "AXRows",
        "AXVisibleRows",
        "AXContents",
        "AXVisibleChildren",
        "AXSelectedChildren",
    ]

    private let registryLock = NSLock()
    private var elementRegistry: [String: AXUIElement] = [:]

    public init() {}

    public func readApplication(pid: Int32, snapshotID: String, options: AccessibilityReadOptions = .init()) throws -> AccessibilityReadResult {
        guard AXIsProcessTrusted() else {
            throw BridgeError(
                code: .permissionMissing,
                message: "Accessibility permission is required to read application controls.",
                suggestedAction: "Grant Accessibility permission to macOS UI Bridge in System Settings."
            )
        }

        let root = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(root, Float(options.timeout))

        var visited = Set<CFHashCode>()
        var elements: [ElementDescriptor] = []
        var truncated = false

        walk(
            root,
            parentIndex: nil,
            depth: 0,
            snapshotID: snapshotID,
            options: options,
            visited: &visited,
            elements: &elements,
            truncated: &truncated
        )

        return AccessibilityReadResult(
            treeQuality: classify(elements: elements, truncated: truncated),
            elements: elements,
            truncated: truncated
        )
    }

    private func walk(
        _ element: AXUIElement,
        parentIndex: Int?,
        depth: Int,
        snapshotID: String,
        options: AccessibilityReadOptions,
        visited: inout Set<CFHashCode>,
        elements: inout [ElementDescriptor],
        truncated: inout Bool
    ) {
        guard depth <= options.maxDepth, elements.count < options.maxElements else {
            truncated = true
            return
        }

        let identity = CFHash(element)
        guard visited.insert(identity).inserted else { return }

        let index = elements.count
        let role = stringAttribute(element, kAXRoleAttribute) ?? "AXUnknown"
        let label = firstNonEmpty([
            stringAttribute(element, kAXTitleAttribute),
            stringAttribute(element, kAXDescriptionAttribute),
            stringAttribute(element, kAXHelpAttribute),
        ])
        let value = role == "AXSecureTextField" ? nil : safeStringValue(copyAttribute(element, kAXValueAttribute))
        let frame = frameAttribute(element)
        let actions = actionNames(element)
        let state = ElementState(
            isEnabled: boolAttribute(element, kAXEnabledAttribute) ?? true,
            isSelected: boolAttribute(element, kAXSelectedAttribute) ?? false,
            isFocused: boolAttribute(element, kAXFocusedAttribute) ?? false,
            isSettable: isSettable(element, attribute: kAXValueAttribute),
            isExpanded: boolAttribute(element, kAXExpandedAttribute)
        )

        let handle = "\(snapshotID):\(index):\(identity)"
        registryLock.withLock {
            elementRegistry[handle] = element
        }

        elements.append(
            ElementDescriptor(
                handle: handle,
                index: index,
                parentIndex: parentIndex,
                role: role,
                label: label,
                value: value,
                frameInWindow: frame,
                state: state,
                actions: actions
            )
        )

        for child in relatedChildren(element) {
            walk(
                child,
                parentIndex: index,
                depth: depth + 1,
                snapshotID: snapshotID,
                options: options,
                visited: &visited,
                elements: &elements,
                truncated: &truncated
            )
            if elements.count >= options.maxElements { break }
        }
    }

    public func element(forHandle handle: String) -> AXUIElement? {
        registryLock.withLock { elementRegistry[handle] }
    }

    public func discard(snapshotID: String) {
        registryLock.withLock {
            elementRegistry = elementRegistry.filter { !$0.key.hasPrefix("\(snapshotID):") }
        }
    }

    private func relatedChildren(_ element: AXUIElement) -> [AXUIElement] {
        var result: [AXUIElement] = []
        var seen = Set<CFHashCode>()

        for attribute in Self.relationshipAttributes {
            guard let values = copyAttribute(element, attribute) as? [AXUIElement] else { continue }
            for value in values where seen.insert(CFHash(value)).inserted {
                result.append(value)
            }
        }
        return result
    }

    private func classify(elements: [ElementDescriptor], truncated: Bool) -> TreeQuality {
        guard !elements.isEmpty else { return .unavailable }
        if elements.count <= 6 { return .shellOnly }

        let structuralRoles = Set(["AXRow", "AXCell", "AXButton", "AXTextField", "AXTextArea", "AXLink"])
        let usefulCount = elements.lazy.filter { structuralRoles.contains($0.role) }.count
        let hasContainer = elements.contains { $0.role == "AXTable" || $0.role == "AXScrollArea" || $0.role == "AXWebArea" }

        if truncated || (hasContainer && usefulCount == 0) { return .partial }
        return usefulCount > 0 ? .complete : .partial
    }

    private func copyAttribute(_ element: AXUIElement, _ attribute: String) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
        return value
    }

    private func stringAttribute(_ element: AXUIElement, _ attribute: String) -> String? {
        copyAttribute(element, attribute) as? String
    }

    private func boolAttribute(_ element: AXUIElement, _ attribute: String) -> Bool? {
        copyAttribute(element, attribute) as? Bool
    }

    private func isSettable(_ element: AXUIElement, attribute: String) -> Bool {
        var settable = DarwinBoolean(false)
        return AXUIElementIsAttributeSettable(element, attribute as CFString, &settable) == .success && settable.boolValue
    }

    private func frameAttribute(_ element: AXUIElement) -> UIBRect? {
        guard
            let positionValue = copyAttribute(element, kAXPositionAttribute),
            let sizeValue = copyAttribute(element, kAXSizeAttribute),
            CFGetTypeID(positionValue) == AXValueGetTypeID(),
            CFGetTypeID(sizeValue) == AXValueGetTypeID()
        else { return nil }

        var position = CGPoint.zero
        var size = CGSize.zero
        guard
            AXValueGetValue(positionValue as! AXValue, .cgPoint, &position),
            AXValueGetValue(sizeValue as! AXValue, .cgSize, &size)
        else { return nil }

        return UIBRect(x: position.x, y: position.y, width: size.width, height: size.height)
    }

    private func actionNames(_ element: AXUIElement) -> [String] {
        var names: CFArray?
        guard AXUIElementCopyActionNames(element, &names) == .success else { return [] }
        return (names as? [String]) ?? []
    }

    private func safeStringValue(_ value: CFTypeRef?) -> String? {
        guard let value else { return nil }
        if let string = value as? String { return string }
        if let number = value as? NSNumber { return number.stringValue }
        return nil
    }

    private func firstNonEmpty(_ values: [String?]) -> String? {
        values.compactMap { value -> String? in
            guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
            return value
        }.first
    }
}
