@preconcurrency import ScreenCaptureKit
import AppKit
import CryptoKit
import Foundation
import UIBridgeProtocol

public struct CapturedWindow: Sendable {
    public let descriptor: ScreenshotDescriptor
    public let pngData: Data

    public init(descriptor: ScreenshotDescriptor, pngData: Data) {
        self.descriptor = descriptor
        self.pngData = pngData
    }
}

public enum WindowCapture {
    public static func capture(windowID: UInt32, handle _: String) async throws -> CapturedWindow {
        guard CGPreflightScreenCaptureAccess() else {
            throw BridgeError(
                code: .permissionMissing,
                message: "Screen Recording permission is required to capture a window.",
                suggestedAction: "Grant Screen Recording permission to UI Bridge in System Settings."
            )
        }

        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
        guard let window = content.windows.first(where: { $0.windowID == windowID }) else {
            throw BridgeError(code: .elementNotFound, message: "Window \(windowID) is not capturable.", retryable: true)
        }

        let scale = NSScreen.main?.backingScaleFactor ?? 2
        let configuration = SCStreamConfiguration()
        configuration.width = max(1, Int(window.frame.width * scale))
        configuration.height = max(1, Int(window.frame.height * scale))
        configuration.showsCursor = false
        configuration.captureResolution = .best

        let filter = SCContentFilter(desktopIndependentWindow: window)
        let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)
        let bitmap = NSBitmapImageRep(cgImage: image)
        guard let data = bitmap.representation(using: .png, properties: [:]) else {
            throw BridgeError(code: .internalFailure, message: "Captured window could not be encoded as PNG.")
        }

        return CapturedWindow(
            descriptor: ScreenshotDescriptor(
                handle: "shot-" + SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined(),
                width: image.width,
                height: image.height
            ),
            pngData: data
        )
    }
}
