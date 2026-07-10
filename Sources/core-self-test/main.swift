import Foundation
import UIBridgeMacCore

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

    print("core-self-test: apps=\(applications.count) windows=\(windows.count) accessibility=\(permissions.accessibilityTrusted) elements=\(elementCount) quality=\(quality)")
} catch {
    fputs("core-self-test failed: \(error)\n", stderr)
    exit(1)
}
