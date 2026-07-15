import Foundation

public enum UIBridgePaths {
    public static let bundleIdentifier = "com.juln.ui-bridge"
    public static let productName = "UI Bridge"
    public static let commandName = "ui-bridge"

    public static var applicationSupportDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/ui-bridge", isDirectory: true)
    }

    public static var stateDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".ui-bridge", isDirectory: true)
    }

    public static func migrateLegacyDataIfNeeded() {
        migrateDirectory(
            from: FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Application Support/app-mcp-bridge", isDirectory: true),
            to: applicationSupportDirectory
        )
        migrateDirectory(
            from: FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(".app-mcp-bridge", isDirectory: true),
            to: stateDirectory
        )
    }

    private static func migrateDirectory(from source: URL, to destination: URL) {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: source.path), source != destination else { return }
        do {
            try fileManager.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
            if !fileManager.fileExists(atPath: destination.path) {
                try fileManager.moveItem(at: source, to: destination)
                return
            }
            try mergeDirectory(from: source, into: destination, fileManager: fileManager)
            try? fileManager.removeItem(at: source)
        } catch {
            // Migration is best-effort. Callers continue with the new location and fail safely if data is unavailable.
        }
    }

    private static func mergeDirectory(from source: URL, into destination: URL, fileManager: FileManager) throws {
        try fileManager.createDirectory(at: destination, withIntermediateDirectories: true)
        for item in try fileManager.contentsOfDirectory(at: source, includingPropertiesForKeys: [.isDirectoryKey]) {
            let destinationItem = destination.appendingPathComponent(item.lastPathComponent)
            let isDirectory = (try? item.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
            if isDirectory {
                try mergeDirectory(from: item, into: destinationItem, fileManager: fileManager)
            } else if !fileManager.fileExists(atPath: destinationItem.path) {
                try fileManager.moveItem(at: item, to: destinationItem)
            }
        }
    }
}
