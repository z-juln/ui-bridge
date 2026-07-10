import Foundation
import CoreGraphics
import UIBridgeMacCore
import UIBridgeProtocol

enum SelfTestFailure: Error, CustomStringConvertible {
    case expectation(String)
    var description: String {
        switch self { case let .expectation(message): message }
    }
}

func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    guard condition() else { throw SelfTestFailure.expectation(message) }
}

do {
    let applications = AppDiscovery.listRunningApplications()
    try expect(!applications.isEmpty, "No running applications were discovered")
    try expect(applications.contains(where: \.isFrontmost), "No frontmost application was identified")

    let windows = WindowDiscovery.listWindows()
    try expect(!windows.isEmpty, "No windows were discovered")
    try expect(windows.allSatisfy { $0.bounds.size.width >= 0 && $0.bounds.size.height >= 0 }, "A window has invalid bounds")

    let permissions = PermissionInspector.current()
    var elementCount = 0
    var quality = "not-tested"
    if permissions.accessibilityTrusted, let frontmost = applications.first(where: \.isFrontmost) {
        let result = try AccessibilityTreeReader().readApplication(
            pid: frontmost.pid,
            snapshotID: "core-self-test",
            options: AccessibilityReadOptions(maxElements: 100, maxDepth: 8)
        )
        try expect(!result.elements.isEmpty, "Accessibility returned an empty tree for the frontmost app")
        try expect(result.elements.map(\.index) == Array(result.elements.indices), "Element indexes are not stable and contiguous")
        elementCount = result.elements.count
        quality = result.treeQuality.rawValue
    }

    let now = Date()
    let before = Snapshot(
        snapshotID: "before",
        appID: "test",
        pid: 1,
        windowID: 1,
        createdAt: now,
        expiresAt: now.addingTimeInterval(60),
        treeQuality: .complete,
        windowBounds: UIBRect(x: 0, y: 0, width: 10, height: 10),
        elements: []
    )
    let after = Snapshot(
        snapshotID: "after",
        appID: "test",
        pid: 1,
        windowID: 1,
        createdAt: now,
        expiresAt: now.addingTimeInterval(60),
        treeQuality: .complete,
        windowBounds: UIBRect(x: 0, y: 0, width: 10, height: 10),
        elements: [ElementDescriptor(handle: "after:0", index: 0, role: "AXStaticText", label: "Ready")]
    )
    let evidence = VerificationEngine.verify(
        expectation: VerificationExpectation(kind: .elementPresent, value: "Ready"),
        before: before,
        after: after
    )
    try expect(evidence?.observed == "Ready", "Verification engine did not observe the expected element")

    var captureBytes = 0
    if CGPreflightScreenCaptureAccess(), let window = windows.first(where: { $0.isVisible && $0.isCapturable }) {
        let capture = try await WindowCapture.capture(windowID: window.windowID, handle: "core-self-test-shot")
        try expect(!capture.pngData.isEmpty, "Window capture returned empty PNG data")
        try expect(capture.descriptor.width > 0 && capture.descriptor.height > 0, "Window capture has invalid dimensions")
        captureBytes = capture.pngData.count
    }

    print("core-self-test: apps=\(applications.count) windows=\(windows.count) accessibility=\(permissions.accessibilityTrusted) elements=\(elementCount) quality=\(quality) captureBytes=\(captureBytes)")
} catch {
    fputs("core-self-test failed: \(error)\n", stderr)
    exit(1)
}
