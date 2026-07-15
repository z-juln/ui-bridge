import Foundation
import UIBridgeMacCore

struct PreviewDiagnosticRecord: Codable, Sendable {
    let createdAt: Date
    let processID: Int32
    let parentProcessID: Int32
    let windowID: UInt32
    let stage: String
    let detail: String?
}

enum PreviewDiagnosticCenter {
    private static var directory: URL {
        UIBridgePaths.applicationSupportDirectory.appendingPathComponent("preview-diagnostics", isDirectory: true)
    }

    static func record(_ stage: String, windowID: UInt32, detail: String? = nil) {
        let record = PreviewDiagnosticRecord(
            createdAt: Date(),
            processID: getpid(),
            parentProcessID: getppid(),
            windowID: windowID,
            stage: stage,
            detail: detail
        )
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let url = directory.appendingPathComponent("\(getpid()).json")
            try JSONEncoder().encode(record).write(to: url, options: .atomic)
            cleanupOldRecords()
        } catch {
            // Diagnostics must never interfere with capture or desktop actions.
        }
    }

    static func recent() -> [PreviewDiagnosticRecord] {
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        ) else { return [] }
        let cutoff = Date().addingTimeInterval(-300)
        return urls.compactMap { url in
            guard let data = try? Data(contentsOf: url),
                  let record = try? JSONDecoder().decode(PreviewDiagnosticRecord.self, from: data),
                  record.createdAt >= cutoff else { return nil }
            return record
        }.sorted { $0.createdAt < $1.createdAt }
    }

    static func clear() {
        try? FileManager.default.removeItem(at: directory)
    }

    private static func cleanupOldRecords() {
        let cutoff = Date().addingTimeInterval(-600)
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey]
        ) else { return }
        for url in urls {
            let date = try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
            if date.map({ $0 < cutoff }) == true {
                try? FileManager.default.removeItem(at: url)
            }
        }
    }
}
