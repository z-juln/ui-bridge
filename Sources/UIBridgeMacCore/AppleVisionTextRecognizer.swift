@preconcurrency import Vision
import Foundation
import ImageIO
import UIBridgeProtocol

public struct AppleVisionTextRecognizer: Sendable {
    public init() {}

    public func recognize(pngData: Data, windowSize: UIBSize) throws -> [VisualTextRegion] {
        guard let source = CGImageSourceCreateWithData(pngData as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw BridgeError(code: .invalidRequest, message: "Screenshot data is not a readable image.")
        }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["zh-Hans", "en-US"]
        request.usesLanguageCorrection = true
        request.minimumTextHeight = 0.006

        let handler = VNImageRequestHandler(cgImage: image, orientation: .up, options: [:])
        try handler.perform([request])

        let imageSize = UIBSize(width: Double(image.width), height: Double(image.height))
        return (request.results ?? []).compactMap { observation in
            guard let candidate = observation.topCandidates(1).first else { return nil }
            let screenshotFrame = Self.frame(
                normalized: observation.boundingBox,
                targetSize: imageSize
            )
            let windowFrame = Self.scale(
                screenshotFrame,
                from: imageSize,
                to: windowSize
            )
            return VisualTextRegion(
                text: candidate.string,
                confidence: Double(candidate.confidence),
                screenshotFrame: screenshotFrame,
                windowFrame: windowFrame
            )
        }.sorted { lhs, rhs in
            if abs(lhs.screenshotFrame.origin.y - rhs.screenshotFrame.origin.y) > 2 {
                return lhs.screenshotFrame.origin.y < rhs.screenshotFrame.origin.y
            }
            return lhs.screenshotFrame.origin.x < rhs.screenshotFrame.origin.x
        }
    }

    public static func frame(normalized: CGRect, targetSize: UIBSize) -> UIBRect {
        UIBRect(
            x: normalized.minX * targetSize.width,
            y: (1 - normalized.maxY) * targetSize.height,
            width: normalized.width * targetSize.width,
            height: normalized.height * targetSize.height
        )
    }

    public static func scale(_ frame: UIBRect, from source: UIBSize, to target: UIBSize) -> UIBRect {
        guard source.width > 0, source.height > 0 else {
            return UIBRect(x: 0, y: 0, width: 0, height: 0)
        }
        return UIBRect(
            x: frame.origin.x / source.width * target.width,
            y: frame.origin.y / source.height * target.height,
            width: frame.size.width / source.width * target.width,
            height: frame.size.height / source.height * target.height
        )
    }
}
