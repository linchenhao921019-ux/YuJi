import Foundation

enum SafetyPolicy {
    private static let protectedNames: Set<String> = [
        "addressbook", "apple", "callhistorydb", "callhistorytransactions",
        "clouddocs", "corefollowup", "differentialprivacy", "dock", "facetime",
        "fileprovider", "icloud", "ilifemediabrowser", "knowledge", "mobilesync",
        "notificationcenter", "siri", "shared", "syncservices", "systemconfiguration",
        "tcc", "trial", "weather", "webpushd"
    ]

    private static let protectedPrefixes = [
        "com.apple.", "group.com.apple.", "apple.", "system."
    ]

    private static let sensitiveNames: Set<String> = [
        "accounts", "autofill", "backups", "bookmarks", "cookies", "credentials",
        "databases", "gamesaves", "history", "keychains", "login data", "profiles",
        "recovery", "saves", "sessions", "wallet", "wallets", "worlds"
    ]

    private static let approvedResidueRoots: [URL] = {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return [
            home.appending(path: "Library/Application Support"),
            home.appending(path: "Library/WebKit"),
            home.appending(path: "Library/HTTPStorages"),
            home.appending(path: "Library/Logs"),
            home.appending(path: "Library/Saved Application State"),
            home.appending(path: "Library/Preferences"),
            home.appending(path: "Library/Cookies"),
            URL(fileURLWithPath: "/Library/Application Support"),
            URL(fileURLWithPath: "/Library/Logs"),
            URL(fileURLWithPath: "/Library/Preferences")
        ].map(\.standardizedFileURL)
    }()

    static func isProtectedName(_ name: String) -> Bool {
        let lower = name.lowercased()
        return protectedNames.contains(lower) || protectedPrefixes.contains { lower.hasPrefix($0) }
    }

    static func isProtectedPath(_ path: String) -> Bool {
        let url = URL(fileURLWithPath: path).standardizedFileURL
        let standardized = url.path
        let resolved = url.resolvingSymlinksInPath().path
        let systemRoots = [
            "/System", "/usr", "/bin", "/sbin", "/private", "/var", "/etc", "/tmp", "/Library/Apple"
        ]
        if systemRoots.contains(where: {
            standardized == $0 || standardized.hasPrefix($0 + "/") ||
                resolved == $0 || resolved.hasPrefix($0 + "/")
        }) {
            return true
        }
        return [standardized, resolved].contains { candidate in
            candidate.split(separator: "/").contains { isProtectedName(String($0)) }
        }
    }

    static func isApprovedUserCachePath(_ path: String) -> Bool {
        let url = URL(fileURLWithPath: path).standardizedFileURL
        let standardized = url.path
        let cacheRoot = FileManager.default.homeDirectoryForCurrentUser
            .appending(path: "Library/Caches")
            .standardizedFileURL.path
        return standardized.hasPrefix(cacheRoot + "/") &&
            !isProtectedPath(standardized) &&
            !isSymbolicLink(url)
    }

    /// Residue cleanup is restricted to a single item immediately below a known
    /// application-data root. This prevents a malformed result from ever moving a
    /// broad Library or system directory to the Trash.
    static func isApprovedResiduePath(_ path: String) -> Bool {
        let url = URL(fileURLWithPath: path).standardizedFileURL
        guard !isProtectedPath(url.path), !isSymbolicLink(url) else { return false }
        return approvedResidueRoots.contains { root in
            url.deletingLastPathComponent().path == root.path
        }
    }

    static func containsSensitiveUserData(at url: URL, fileManager fm: FileManager = .default) -> Bool {
        let ownName = normalizedSensitiveName(url.deletingPathExtension().lastPathComponent)
        if sensitiveNames.contains(ownName) { return true }

        guard let children = try? fm.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
        ) else { return false }

        return children.prefix(80).contains { child in
            let name = normalizedSensitiveName(child.deletingPathExtension().lastPathComponent)
            return sensitiveNames.contains(name)
        }
    }

    static func isSymbolicLink(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) == true
    }

    private static func normalizedSensitiveName(_ value: String) -> String {
        value.replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }
}
