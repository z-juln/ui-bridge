import Darwin
import Foundation
import UIBridgeMacCore

public struct ServiceStateStore: Sendable {
    public let directory: URL
    public var pidFile: URL { directory.appendingPathComponent("service.pid") }
    public var logFile: URL { directory.appendingPathComponent("service.log") }

    public init(directory: URL? = nil) {
        if directory == nil { UIBridgePaths.migrateLegacyDataIfNeeded() }
        self.directory = directory ?? UIBridgePaths.stateDirectory
    }

    public func runningPID() -> Int32? {
        guard let string = try? String(contentsOf: pidFile, encoding: .utf8),
              let pid = Int32(string.trimmingCharacters(in: .whitespacesAndNewlines)),
              kill(pid, 0) == 0 else { return nil }
        return pid
    }

    public func save(pid: Int32) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try String(pid).write(to: pidFile, atomically: true, encoding: .utf8)
    }

    public func clear() {
        try? FileManager.default.removeItem(at: pidFile)
    }

    public func stop() throws -> Bool {
        guard let pid = runningPID() else {
            clear()
            return false
        }
        guard kill(pid, SIGTERM) == 0 else {
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
        }
        clear()
        return true
    }
}
