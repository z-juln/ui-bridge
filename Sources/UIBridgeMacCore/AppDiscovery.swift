import AppKit
import Foundation
import UIBridgeProtocol

public enum AppDiscovery {
    public static func listRunningApplications() -> [AppDescriptor] {
        let frontmostPID = NSWorkspace.shared.frontmostApplication?.processIdentifier

        return NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy != .prohibited }
            .map { application in
                AppDescriptor(
                    appID: application.bundleIdentifier ?? "pid:\(application.processIdentifier)",
                    pid: application.processIdentifier,
                    name: application.localizedName ?? application.bundleIdentifier ?? "Unknown",
                    bundleURL: application.bundleURL,
                    isRunning: !application.isTerminated,
                    isFrontmost: application.processIdentifier == frontmostPID
                )
            }
            .sorted {
                if $0.isFrontmost != $1.isFrontmost { return $0.isFrontmost }
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
    }
}
