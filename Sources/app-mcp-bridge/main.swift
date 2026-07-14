import AppKit
import Foundation
import UIBridgeMacCore
import UIBridgeMCP
import UIBridgeServer

@main
enum UIBridgeCommand {
    @MainActor private static var appShell: AppShell?

    static func main() async {
        do {
            try await run()
        } catch {
            FileHandle.standardError.write(Data("app-mcp-bridge: \(error.localizedDescription)\n".utf8))
            Foundation.exit(EXIT_FAILURE)
        }
    }

    @MainActor private static func run() async throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        let executablePath = URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL.path
        let isBundledAppLaunch = arguments.isEmpty && (
            Bundle.main.bundleIdentifier == "com.juln.app-mcp-bridge"
                || executablePath.contains(".app/Contents/MacOS/")
        )
        let command = arguments.first ?? (isBundledAppLaunch ? "app" : "help")
        let tokenStore = TokenStore()

        switch command {
        case "version":
            print("app-mcp-bridge 0.1.0-dev")
        case "permissions":
            let status = PermissionInspector.current()
            print("accessibility=\(status.accessibilityTrusted) screenCapture=\(status.screenCaptureAllowed == true)")
        case "token":
            let token = arguments.contains("--rotate") ? try tokenStore.rotate() : try tokenStore.loadOrCreate()
            print(token)
        case "serve":
            let port = parsePort(arguments) ?? 8765
            let token = try tokenStore.loadOrCreate()
            let server = try await HTTPServer.make(port: port, token: token)
            try server.start()
            print("app-mcp-bridge listening on http://127.0.0.1:\(port)")
            while !Task.isCancelled {
                try await Task.sleep(for: .seconds(3_600))
            }
        case "app":
            let token = try tokenStore.loadOrCreate()
            let server = try await HTTPServer.make(port: 8765, token: token)
            try server.start()
            let state = ServiceStateStore()
            try state.save(pid: getpid())
            defer { state.clear() }
            appShell = AppShell(token: token)
            appShell?.run()
        case "mcp":
            try await MCPBridge.runStdio()
        case "call":
            guard arguments.indices.contains(1) else {
                throw LocalBridgeClientError.invalidArguments("usage: app-mcp-bridge call <tool> ['{...}'] [--port 8765]")
            }
            let token = try tokenStore.loadOrCreate()
            let data = try await LocalBridgeClient(token: token, port: parsePort(arguments) ?? 8765).call(
                tool: arguments[1],
                argumentsJSON: arguments.indices.contains(2) && !arguments[2].hasPrefix("--") ? arguments[2] : nil
            )
            print(String(decoding: data, as: UTF8.self))
        case "show":
            try FileManager.default.createDirectory(
                at: AppShell.showSettingsRequestURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let requestedSection = arguments.indices.contains(1) ? arguments[1] : "overview"
            try Data(requestedSection.utf8).write(to: AppShell.showSettingsRequestURL, options: .atomic)
            NSRunningApplication.runningApplications(withBundleIdentifier: "com.juln.app-mcp-bridge")
                .first?
                .activate(options: [.activateAllWindows])
            DistributedNotificationCenter.default().postNotificationName(
                AppShell.showSettingsNotification,
                object: nil,
                deliverImmediately: true
            )
        case "preview-stream":
            guard arguments.indices.contains(1), let windowID = UInt32(arguments[1]) else {
                throw LocalBridgeClientError.invalidArguments("preview-stream requires a window id")
            }
            try await PreviewStreamCommand.run(windowID: windowID)
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
            print("app-mcp-bridge <start|stop|serve|mcp|call|show|status|permissions|token|version>")
        }
    }

    private static func parsePort(_ arguments: [String]) -> UInt16? {
        guard let index = arguments.firstIndex(of: "--port"), arguments.indices.contains(index + 1) else { return nil }
        return UInt16(arguments[index + 1])
    }
}
