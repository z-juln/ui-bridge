import Foundation

public struct VisualTextRegion: Codable, Hashable, Sendable {
    public let text: String
    public let confidence: Double
    public let screenshotFrame: UIBRect
    public let windowFrame: UIBRect

    public init(text: String, confidence: Double, screenshotFrame: UIBRect, windowFrame: UIBRect) {
        self.text = text
        self.confidence = confidence
        self.screenshotFrame = screenshotFrame
        self.windowFrame = windowFrame
    }
}

public struct VisualTextQueryResult: Codable, Hashable, Sendable {
    public let snapshotID: String
    public let provider: String
    public let durationMilliseconds: Double
    public let isCached: Bool
    public let regions: [VisualTextRegion]

    public init(snapshotID: String, provider: String, durationMilliseconds: Double, isCached: Bool, regions: [VisualTextRegion]) {
        self.snapshotID = snapshotID
        self.provider = provider
        self.durationMilliseconds = durationMilliseconds
        self.isCached = isCached
        self.regions = regions
    }
}
