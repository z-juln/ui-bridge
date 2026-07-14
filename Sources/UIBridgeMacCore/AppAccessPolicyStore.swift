import Foundation

public struct AppAccessPolicy: Codable, Sendable {
    public var defaultAllow: Bool
    public var rules: [String: Bool]

    public init(defaultAllow: Bool = true, rules: [String: Bool] = [:]) {
        self.defaultAllow = defaultAllow
        self.rules = rules
    }

    public func allows(appID: String) -> Bool {
        rules[appID] ?? defaultAllow
    }
}

public enum AppAccessPolicyStore {
    public static func load() -> AppAccessPolicy {
        guard let data = try? Data(contentsOf: url),
              let policy = try? JSONDecoder().decode(AppAccessPolicy.self, from: data) else {
            return AppAccessPolicy()
        }
        return policy
    }

    public static func save(_ policy: AppAccessPolicy) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(policy).write(to: url, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }

    public static func setDefaultAllow(_ allowed: Bool) throws {
        var policy = load()
        policy.defaultAllow = allowed
        try save(policy)
    }

    public static func setAllowed(_ allowed: Bool?, appID: String) throws {
        var policy = load()
        policy.rules[appID] = allowed
        try save(policy)
    }

    private static var url: URL {
        if let override = ProcessInfo.processInfo.environment["APP_MCP_BRIDGE_ACCESS_POLICY_PATH"], !override.isEmpty {
            return URL(fileURLWithPath: override)
        }
        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/app-mcp-bridge", isDirectory: true)
            .appendingPathComponent("app-access.json")
    }
}
