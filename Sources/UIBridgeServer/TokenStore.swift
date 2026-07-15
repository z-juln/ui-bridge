import Foundation
import UIBridgeMacCore

public struct TokenStore: Sendable {
    public let tokenFile: URL

    public init(tokenFile: URL? = nil) {
        if tokenFile == nil { UIBridgePaths.migrateLegacyDataIfNeeded() }
        self.tokenFile = tokenFile ?? UIBridgePaths.stateDirectory.appendingPathComponent("token", isDirectory: false)
    }

    public func loadOrCreate() throws -> String {
        if let token = try? String(contentsOf: tokenFile, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines), !token.isEmpty {
            return token
        }

        let directory = tokenFile.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let token = UUID().uuidString.replacingOccurrences(of: "-", with: "")
            + UUID().uuidString.replacingOccurrences(of: "-", with: "")
        try token.write(to: tokenFile, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: tokenFile.path)
        return token
    }

    public func rotate() throws -> String {
        try? FileManager.default.removeItem(at: tokenFile)
        return try loadOrCreate()
    }
}
