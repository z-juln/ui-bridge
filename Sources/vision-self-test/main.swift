import Foundation
import UIBridgeMacCore
import UIBridgeProtocol

enum VisionSelfTestError: Error, CustomStringConvertible {
    case failed(String)

    var description: String {
        switch self {
        case .failed(let message): message
        }
    }
}

@main
struct VisionSelfTest {
    static func main() async throws {
        let arguments = CommandLine.arguments
        let bundleID = value(after: "--bundle-id", in: arguments) ?? "com.juln.ui-bridge"
        let expected = value(after: "--expect", in: arguments)
        let rounds = Int(value(after: "--rounds", in: arguments) ?? "3") ?? 3

        guard let app = AppDiscovery.listRunningApplications().first(where: { $0.appID == bundleID }) else {
            throw VisionSelfTestError.failed("No running application found for \(bundleID)")
        }
        guard let window = WindowDiscovery.listWindows(pid: app.pid).first(where: { $0.isVisible && $0.isCapturable }) else {
            throw VisionSelfTestError.failed("No visible capturable window found for \(bundleID)")
        }

        let capture = try await WindowCapture.capture(windowID: window.windowID, handle: "vision-self-test")
        let recognizer = AppleVisionTextRecognizer()
        var durations: [Double] = []
        var regions: [VisualTextRegion] = []

        for _ in 0..<max(1, rounds) {
            let start = ContinuousClock.now
            regions = try recognizer.recognize(pngData: capture.pngData, windowSize: window.bounds.size)
            durations.append(milliseconds(from: start.duration(to: .now)))
        }

        guard !regions.isEmpty else {
            throw VisionSelfTestError.failed("Apple Vision returned no text regions")
        }
        let screenshotSize = UIBSize(width: Double(capture.descriptor.width), height: Double(capture.descriptor.height))
        guard regions.allSatisfy({ isInside($0.screenshotFrame, size: screenshotSize) && isInside($0.windowFrame, size: window.bounds.size) }) else {
            throw VisionSelfTestError.failed("At least one text region is outside the current screenshot or window")
        }

        if let expected, !regions.contains(where: { $0.text.localizedCaseInsensitiveContains(expected) }) {
            throw VisionSelfTestError.failed("Expected text '\(expected)' was not recognized")
        }

        var alignedWithAccessibility = false
        if let expected {
            let read = try AccessibilityTreeReader().readWindow(
                pid: app.pid,
                snapshotID: "vision-self-test",
                windowBounds: window.bounds,
                options: AccessibilityReadOptions(maxElements: 1_000, maxDepth: 20)
            )
            let accessibilityFrames = read.elements.compactMap { element -> UIBRect? in
                let matches = element.label?.localizedCaseInsensitiveContains(expected) == true
                    || element.value?.localizedCaseInsensitiveContains(expected) == true
                return matches ? element.frameInWindow : nil
            }
            let recognizedFrames = regions.filter { $0.text.localizedCaseInsensitiveContains(expected) }.map(\.windowFrame)
            alignedWithAccessibility = recognizedFrames.contains { recognized in
                accessibilityFrames.contains { accessibility in
                    contains(accessibility, point: center(of: recognized), tolerance: 8)
                }
            }
            guard alignedWithAccessibility else {
                throw VisionSelfTestError.failed("Recognized text '\(expected)' did not align with its accessibility region")
            }
        }

        let sample = regions.prefix(12).map { region in
            "\(region.text){\(Int(region.windowFrame.origin.x)),\(Int(region.windowFrame.origin.y)),\(Int(region.windowFrame.size.width))x\(Int(region.windowFrame.size.height))}"
        }.joined(separator: " | ")
        let cold = durations.first ?? 0
        let warm = durations.dropFirst().min() ?? cold
        print("vision-self-test: provider=apple_vision app=\(app.name) window=\(window.title) regions=\(regions.count) cold_ms=\(Int(cold)) warm_ms=\(Int(warm)) ax_aligned=\(alignedWithAccessibility) sample=\(sample)")
    }

    private static func value(after flag: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: flag), arguments.indices.contains(index + 1) else { return nil }
        return arguments[index + 1]
    }

    private static func milliseconds(from duration: Duration) -> Double {
        let components = duration.components
        return Double(components.seconds) * 1_000 + Double(components.attoseconds) / 1_000_000_000_000_000
    }

    private static func isInside(_ frame: UIBRect, size: UIBSize) -> Bool {
        frame.origin.x >= 0
            && frame.origin.y >= 0
            && frame.origin.x + frame.size.width <= size.width + 1
            && frame.origin.y + frame.size.height <= size.height + 1
    }

    private static func center(of frame: UIBRect) -> UIBPoint {
        UIBPoint(x: frame.origin.x + frame.size.width / 2, y: frame.origin.y + frame.size.height / 2)
    }

    private static func contains(_ frame: UIBRect, point: UIBPoint, tolerance: Double) -> Bool {
        point.x >= frame.origin.x - tolerance
            && point.y >= frame.origin.y - tolerance
            && point.x <= frame.origin.x + frame.size.width + tolerance
            && point.y <= frame.origin.y + frame.size.height + tolerance
    }
}
