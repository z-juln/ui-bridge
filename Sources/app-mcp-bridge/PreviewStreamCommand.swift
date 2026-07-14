@preconcurrency import ScreenCaptureKit
import AppKit
import CoreImage
import CoreMedia
import Foundation

enum PreviewStreamCommand {
    static func run(windowID: UInt32) async throws {
        PreviewDiagnosticCenter.record("worker_started", windowID: windowID)
        let writer = PreviewFrameWriter()
        let content = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: true)
        guard let window = content.windows.first(where: { $0.windowID == windowID }) else {
            throw NSError(domain: "AppMCPBridge", code: 2, userInfo: [NSLocalizedDescriptionKey: "目标窗口已关闭或不可捕获"])
        }
        PreviewDiagnosticCenter.record("worker_window_found", windowID: windowID)
        writer.windowID = windowID

        let maximumWidth = 720.0
        let scale = min(2.0, maximumWidth / max(1, window.frame.width))
        let configuration = SCStreamConfiguration()
        configuration.width = max(1, Int(window.frame.width * scale))
        configuration.height = max(1, Int(window.frame.height * scale))
        configuration.minimumFrameInterval = CMTime(value: 1, timescale: 1)
        configuration.queueDepth = 2
        configuration.showsCursor = false
        configuration.pixelFormat = kCVPixelFormatType_32BGRA

        let stream = SCStream(
            filter: SCContentFilter(desktopIndependentWindow: window),
            configuration: configuration,
            delegate: writer
        )
        try stream.addStreamOutput(writer, type: .screen, sampleHandlerQueue: writer.queue)
        try await stream.startCapture()
        PreviewDiagnosticCenter.record("worker_stream_started", windowID: windowID)
        while !Task.isCancelled {
            try await Task.sleep(for: .seconds(3_600))
        }
        try? await stream.stopCapture()
    }
}

private final class PreviewFrameWriter: NSObject, SCStreamOutput, SCStreamDelegate, @unchecked Sendable {
    let queue = DispatchQueue(label: "com.juln.app-mcp-bridge.preview-service", qos: .userInitiated)
    private let imageContext = CIContext(options: [.cacheIntermediates: false])
    private let output = FileHandle.standardOutput
    var windowID: UInt32 = 0
    private var wroteFirstFrame = false

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of outputType: SCStreamOutputType) {
        guard outputType == .screen,
              sampleBuffer.isValid,
              let pixelBuffer = sampleBuffer.imageBuffer else { return }
        let image = CIImage(cvPixelBuffer: pixelBuffer)
        guard let cgImage = imageContext.createCGImage(image, from: image.extent) else { return }
        let bitmap = NSBitmapImageRep(cgImage: cgImage)
        guard let data = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.52]),
              data.count <= Int(UInt32.max) else { return }
        var length = UInt32(data.count).bigEndian
        let header = Data(bytes: &length, count: MemoryLayout<UInt32>.size)
        try? output.write(contentsOf: header)
        try? output.write(contentsOf: data)
        if !wroteFirstFrame {
            wroteFirstFrame = true
            PreviewDiagnosticCenter.record("worker_first_frame_written", windowID: windowID, detail: "bytes=\(data.count)")
        }
    }

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        FileHandle.standardError.write(Data((error.localizedDescription + "\n").utf8))
        Foundation.exit(EXIT_FAILURE)
    }
}
