import Foundation
import UIBridgeMacCore
import UIBridgeMCP
import UIBridgeServer

@main
enum UIBridgeCommand {
    static func main() async throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        let executablePath = URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL.path
        let isBundledAppLaunch = arguments.isEmpty && (
            Bundle.main.bundleIdentifier == "com.juln.macos-ui-bridge"
                || executablePath.contains(".app/Contents/MacOS/")
        )
        let command = arguments.first ?? (isBundledAppLaunch ? "app" : "help")
        let tokenStore = TokenStore()

        switch command {
        case "version":
            print("macos-ui-bridge 0.1.0-dev")
        case "permissions":
            let status = PermissionInspector.current()
            print("accessibility=\(status.accessibilityTrusted) screenCapture=\(status.screenCaptureAllowed == true)")
        case "token":
            let token = arguments.contains("--rotate") ? try tokenStore.rotate() : try tokenStore.loadOrCreate()
            print(token)
        case "serve":
            let port = parsePort(arguments) ?? 8765
            let token = try tokenStore.loadOrCreate()
            let server = HTTPServer(port: port, token: token)
            try server.start()
            print("macos-ui-bridge listening on http://127.0.0.1:\(port)")
            while !Task.isCancelled {
                try await Task.sleep(for: .seconds(3_600))
            }
        case "app":
            let token = try tokenStore.loadOrCreate()
            let server = HTTPServer(port: 8765, token: token)
            try server.start()
            while !Task.isCancelled {
                try await Task.sleep(for: .seconds(3_600))
            }
        case "mcp":
            try await MCPBridge.runStdio()
        case "start":
            let port = parsePort(arguments) ?? 8765
            let state = ServiceStateStore()
            if let pid = state.runningPID() {
                print("already running pid=\(pid)")
                return
            }
            let process = Process()
            process.executableURL = URL(fileURLWithPath: CommandLine.arguments[0])
            process.arguments = ["serve", "--port", String(port)]
            try FileManager.default.createDirectory(at: state.directory, withIntermediateDirectories: true)
            if !FileManager.default.fileExists(atPath: state.logFile.path) {
                FileManager.default.createFile(atPath: state.logFile.path, contents: nil)
            }
            let log = try FileHandle(forWritingTo: state.logFile)
            try log.seekToEnd()
            process.standardOutput = log
            process.standardError = log
            try process.run()
            try state.save(pid: process.processIdentifier)
            print("started pid=\(process.processIdentifier) port=\(port)")
        case "stop":
            let stopped = try ServiceStateStore().stop()
            print(stopped ? "stopped" : "not running")
        case "status":
            if let pid = ServiceStateStore().runningPID() {
                print("running pid=\(pid)")
            } else {
                print("not running")
            }
        default:
            print("macos-ui-bridge <start|stop|serve|mcp|status|permissions|token|version>")
        }
    }

    private static func parsePort(_ arguments: [String]) -> UInt16? {
        guard let index = arguments.firstIndex(of: "--port"), arguments.indices.contains(index + 1) else { return nil }
        return UInt16(arguments[index + 1])
    }
}
