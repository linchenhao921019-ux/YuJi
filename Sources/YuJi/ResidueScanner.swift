import AppKit
import Darwin
import Foundation

struct ScanOutput: Sendable {
    let results: [AppResidue]
    let inaccessibleLocations: Int
    let inspectedLocations: Int
    let protectedCandidates: Int
    let duration: TimeInterval
}

private struct InstalledInventory: Sendable {
    var fingerprints = Set<String>()
    var displayNames: [String: String] = [:]
}

private struct DirectoryStats: Sendable {
    let size: Int64
    let count: Int
    let modified: Date?
}

enum ResidueScanner {
    private static let genericNames: Set<String> = [
        "cache", "caches", "logs", "data", "library", "application support",
        "preferences", "temporaryitems", "saved application state", "users",
        "crashreporter", "webkit", "httpstorages", "containers", "group containers"
    ]

    private static let protectedFragments = [
        "com.apple", "group.com.apple", "apple.", "icloud", "cloudkit",
        "coreservices", "systempreferences", "mobileasset", "siri", "spotlight",
        "wallpaper", "weather", "photos", "mail", "messages", "facetime",
        "calendar", "reminders", "notes", "findmy", "storekit", "geod"
        , "ilifemediabrowser"
    ]

    static func scan() -> ScanOutput {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser
        let startedAt = Date()
        // Batched disk accounting removes most process-launch overhead, so the scan
        // can cover more roots while retaining a firm responsiveness budget.
        let deadline = startedAt.addingTimeInterval(28)
        let installed = installedInventory(fileManager: fm, home: home)
        let roots: [(URL, Int)]
        if let testRoot = ProcessInfo.processInfo.environment["YUJI_SCAN_ROOT"] {
            roots = [(URL(fileURLWithPath: testRoot), 18)]
        } else {
            roots = defaultScanRoots(home: home)
        }

        var candidates: [AppResidue] = []
        var inaccessible = 0
        var inspected = 0
        var protectedCandidates = 0

        let cacheRoot: URL?
        if let testCacheRoot = ProcessInfo.processInfo.environment["YUJI_CACHE_SCAN_ROOT"] {
            cacheRoot = URL(fileURLWithPath: testCacheRoot)
        } else if ProcessInfo.processInfo.environment["YUJI_SCAN_ROOT"] != nil {
            cacheRoot = nil
        } else {
            cacheRoot = home.appending(path: "Library/Caches")
        }
        if let cacheRoot {
            let cacheOutput = scanCaches(
                root: cacheRoot,
                installed: installed,
                fileManager: fm,
                deadline: deadline
            )
            candidates.append(contentsOf: cacheOutput.items)
            inaccessible += cacheOutput.inaccessible
            inspected += cacheOutput.inspected
        }

        rootLoop: for (root, rootWeight) in roots {
            if Date() >= deadline { break rootLoop }
            guard let children = try? fm.contentsOfDirectory(
                at: root,
                includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey, .nameKey],
                options: [.skipsHiddenFiles]
            ) else {
                inaccessible += 1
                continue
            }
            let prioritized = children.sorted {
                (modificationDate($0) ?? .distantFuture) < (modificationDate($1) ?? .distantFuture)
            }
            let eligible = prioritized.filter { child in
                let rawName = child.lastPathComponent
                let normalized = normalize(rawName)
                return normalized.count >= 4 &&
                    !isUUIDName(rawName) &&
                    !genericNames.contains(rawName.lowercased()) &&
                    !SafetyPolicy.isProtectedName(rawName) &&
                    !SafetyPolicy.isProtectedPath(child.path) &&
                    !SafetyPolicy.isSymbolicLink(child) &&
                    !protectedFragments.contains(where: { rawName.lowercased().contains($0) }) &&
                    !matchesInstalled(normalized, installed: installed.fingerprints)
            }
            let measured = directoryStatsBatch(eligible, fileManager: fm, deadline: deadline)
            inspected += eligible.count

            for child in eligible {
                if Date() >= deadline { break rootLoop }
                let rawName = child.lastPathComponent
                let stats = measured[child.path] ?? quickStats(child)
                let isEmpty = stats.size == 0 && isEffectivelyEmptyDirectory(child, fileManager: fm, deadline: deadline)
                let minimumSize: Int64 = 512 * 1024
                guard isEmpty || stats.size >= minimumSize else { continue }

                let modified = stats.modified ?? modificationDate(child)
                let daysOld = modified.map { Calendar.current.dateComponents([.day], from: $0, to: Date()).day ?? 0 } ?? 0
                if isEmpty && daysOld < 30 { continue }
                var confidence = 48 + rootWeight
                var evidence = ["未在常见位置找到对应应用"]

                if isEmpty {
                    confidence = min(confidence, 76)
                    evidence.append("目录为空，未发现有效内容")
                }

                if daysOld >= 365 {
                    confidence += 17
                    evidence.append("超过一年未更新")
                } else if daysOld >= 90 {
                    confidence += 11
                    evidence.append("超过三个月未更新")
                } else if daysOld < 30 {
                    confidence -= 13
                    evidence.append("目录近期仍有更新")
                }

                if stats.size >= 50 * 1024 * 1024 {
                    confidence += 5
                    evidence.append("残留占用较大")
                }
                if rawName.contains(".") || rawName.lowercased().contains("app") {
                    confidence += 4
                    evidence.append("目录包含应用标识特征")
                }

                let containsSensitiveData = SafetyPolicy.containsSensitiveUserData(at: child, fileManager: fm)
                if containsSensitiveData {
                    confidence = min(confidence, 69)
                    evidence.append("检测到可能包含个人数据的内容，建议清理前人工确认")
                    protectedCandidates += 1
                }

                confidence = min(max(confidence, 55), 98)
                let risk: RiskLevel = !isEmpty && !containsSensitiveData && confidence >= 82 ? .high : .review
                let item = AppResidue(
                    id: UUID(),
                    name: displayName(rawName),
                    bundleHint: rawName,
                    kind: .residue,
                    paths: [ResiduePath(
                        path: child.path,
                        size: stats.size,
                        fileCount: stats.count,
                        modifiedAt: modified,
                        isEmptyDirectory: isEmpty
                    )],
                    confidence: confidence,
                    risk: risk,
                    evidence: evidence,
                    containsSensitiveData: containsSensitiveData
                )
                candidates.append(item)
            }
        }

        let merged = merge(candidates)
            .sorted {
                if $0.risk != $1.risk { return $0.risk == .high }
                return $0.totalSize > $1.totalSize
            }
        return ScanOutput(
            results: Array(merged.prefix(500)),
            inaccessibleLocations: inaccessible,
            inspectedLocations: inspected,
            protectedCandidates: protectedCandidates,
            duration: Date().timeIntervalSince(startedAt)
        )
    }

    // macOS 26 protects other apps' private Containers with the separate,
    // per-use SystemPolicyAppData prompt. Routine scans deliberately avoid
    // Containers and Group Containers so a scan never asks for that access.
    static func defaultScanRoots(home: URL) -> [(URL, Int)] {
        [
            (home.appending(path: "Library/Application Support"), 18),
            (home.appending(path: "Library/WebKit"), 10),
            (home.appending(path: "Library/HTTPStorages"), 8),
            (home.appending(path: "Library/Logs"), 7),
            (home.appending(path: "Library/Saved Application State"), 7),
            (URL(fileURLWithPath: "/Library/Application Support"), 14),
            (URL(fileURLWithPath: "/Library/Logs"), 6)
        ]
    }

    private static func installedInventory(fileManager fm: FileManager, home: URL) -> InstalledInventory {
        let roots = [
            URL(fileURLWithPath: "/Applications"),
            home.appending(path: "Applications"),
            URL(fileURLWithPath: "/System/Applications")
        ]
        var inventory = InstalledInventory()
        var queue = roots.map { ($0, 0) }

        while !queue.isEmpty {
            let (directory, depth) = queue.removeFirst()
            guard let children = try? fm.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) else { continue }

            for url in children {
                if url.pathExtension.lowercased() != "app" {
                    if depth < 1,
                       (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
                        queue.append((url, depth + 1))
                    }
                    continue
                }
                let name = url.deletingPathExtension().lastPathComponent
                let normalizedName = normalize(name)
                inventory.fingerprints.insert(normalizedName)
                inventory.displayNames[normalizedName] = name
                if let bundle = Bundle(url: url), let identifier = bundle.bundleIdentifier {
                    let normalizedIdentifier = normalize(identifier)
                    inventory.fingerprints.insert(normalizedIdentifier)
                    inventory.displayNames[normalizedIdentifier] = name
                    identifier.split(separator: ".").forEach {
                        let part = normalize(String($0))
                        if part.count >= 5 {
                            inventory.fingerprints.insert(part)
                            inventory.displayNames[part] = name
                        }
                    }
                }
            }
        }
        return inventory
    }

    private static func scanCaches(
        root: URL,
        installed: InstalledInventory,
        fileManager fm: FileManager,
        deadline: Date
    ) -> (items: [AppResidue], inaccessible: Int, inspected: Int) {
        guard let children = try? fm.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return ([], 1, 0) }

        var items: [AppResidue] = []
        let eligible = children.filter { child in
            let rawName = child.lastPathComponent
            let normalized = normalize(rawName)
            return normalized.count >= 3 &&
                rawName != Bundle.main.bundleIdentifier &&
                !isUUIDName(rawName) &&
                !SafetyPolicy.isProtectedName(rawName) &&
                !SafetyPolicy.isProtectedPath(child.path) &&
                !SafetyPolicy.isSymbolicLink(child) &&
                !protectedFragments.contains(where: { rawName.lowercased().contains($0) })
        }
        let measured = directoryStatsBatch(eligible, fileManager: fm, deadline: deadline)

        for child in eligible {
            if Date() >= deadline { break }
            let rawName = child.lastPathComponent
            let normalized = normalize(rawName)
            let stats = measured[child.path] ?? quickStats(child)
            guard stats.size >= 1024 * 1024 else { continue }

            let installedName = installedDisplayName(normalized, inventory: installed)
            let name = installedName ?? displayName(rawName)
            var evidence = [
                "位于当前用户的标准缓存目录",
                "删除后应用会在需要时重新生成缓存"
            ]
            evidence.append(installedName == nil ? "未找到对应的已安装应用" : "对应应用仍处于已安装状态")

            items.append(AppResidue(
                id: UUID(),
                name: name,
                bundleHint: rawName,
                kind: .cache,
                paths: [ResiduePath(
                    path: child.path,
                    size: stats.size,
                    fileCount: stats.count,
                    modifiedAt: stats.modified ?? modificationDate(child)
                )],
                confidence: 95,
                risk: .high,
                evidence: evidence
            ))
        }
        return (items, 0, eligible.count)
    }

    private static func installedDisplayName(_ candidate: String, inventory: InstalledInventory) -> String? {
        if let exact = inventory.displayNames[candidate] { return exact }
        let match = inventory.displayNames.keys
            .filter { min(candidate.count, $0.count) >= 5 && (candidate.contains($0) || $0.contains(candidate)) }
            .max(by: { $0.count < $1.count })
        return match.flatMap { inventory.displayNames[$0] }
    }

    private static func matchesInstalled(_ candidate: String, installed: Set<String>) -> Bool {
        installed.contains { fingerprint in
            guard min(candidate.count, fingerprint.count) >= 4 else { return false }
            return candidate.contains(fingerprint) || fingerprint.contains(candidate)
        }
    }

    private static func quickStats(_ url: URL) -> DirectoryStats {
        var rootStat = stat()
        guard lstat(url.path, &rootStat) == 0 else { return DirectoryStats(size: 0, count: 0, modified: nil) }
        let rootType = rootStat.st_mode & mode_t(S_IFMT)
        let rootDate = Date(timeIntervalSince1970: TimeInterval(rootStat.st_mtimespec.tv_sec))
        if rootType == mode_t(S_IFREG) {
            return DirectoryStats(size: Int64(rootStat.st_blocks) * 512, count: 1, modified: rootDate)
        }
        return DirectoryStats(size: 0, count: 0, modified: rootDate)
    }

    /// Measures several top-level candidates with one `du` process. In a typical
    /// Library this cuts process launches by more than an order of magnitude while
    /// preserving per-candidate results and a timeout for pathological directories.
    private static func directoryStatsBatch(
        _ urls: [URL],
        fileManager _: FileManager,
        deadline: Date
    ) -> [String: DirectoryStats] {
        guard !urls.isEmpty else { return [:] }
        var output: [String: DirectoryStats] = [:]

        for offset in stride(from: 0, to: urls.count, by: 18) {
            if Date() >= deadline { break }
            let batch = Array(urls[offset..<min(offset + 18, urls.count)])

            let process = Process()
            let pipe = Pipe()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/du")
            process.arguments = ["-sk"] + batch.map(\.path)
            process.standardOutput = pipe
            process.standardError = FileHandle.nullDevice

            do { try process.run() } catch { continue }
            let localDeadline = min(deadline, Date().addingTimeInterval(1.6))
            let finished = DispatchSemaphore(value: 0)
            DispatchQueue.global(qos: .utility).async {
                process.waitUntilExit()
                finished.signal()
            }
            let remaining = max(0, localDeadline.timeIntervalSinceNow)
            if finished.wait(timeout: .now() + remaining) == .timedOut {
                process.terminate()
                _ = finished.wait(timeout: .now() + 0.15)
            }

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let text = String(data: data, encoding: .utf8) else { continue }
            for line in text.split(separator: "\n", omittingEmptySubsequences: true) {
                guard let split = line.firstIndex(where: { $0 == "\t" || $0 == " " }),
                      let kilobytes = Int64(line[..<split]) else { continue }
                let path = String(line[line.index(after: split)...])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                guard let url = batch.first(where: { $0.path == path }) else { continue }
                let basic = quickStats(url)
                output[url.path] = DirectoryStats(
                    size: kilobytes * 1024,
                    count: basic.count,
                    modified: basic.modified
                )
            }
        }
        return output
    }

    private static func isEffectivelyEmptyDirectory(_ url: URL, fileManager fm: FileManager, deadline: Date) -> Bool {
        var rootStat = stat()
        guard lstat(url.path, &rootStat) == 0,
              rootStat.st_mode & mode_t(S_IFMT) == mode_t(S_IFDIR) else { return false }
        guard let enumerator = fm.enumerator(
            at: url,
            includingPropertiesForKeys: nil,
            options: [.skipsPackageDescendants],
            errorHandler: { _, _ in false }
        ) else { return false }

        let ignored = Set([".DS_Store", ".localized", "Icon\r"])
        var visited = 0
        for case let child as URL in enumerator {
            if Date() >= deadline || visited >= 256 { return false }
            visited += 1
            if ignored.contains(child.lastPathComponent) { continue }

            var info = stat()
            guard lstat(child.path, &info) == 0 else { return false }
            let type = info.st_mode & mode_t(S_IFMT)
            if type == mode_t(S_IFDIR) { continue }
            return false
        }
        return true
    }

    private static func merge(_ items: [AppResidue]) -> [AppResidue] {
        var groups: [String: AppResidue] = [:]
        for item in items {
            let key = "\(item.kind.rawValue):\(mergeKey(item.bundleHint))"
            if let existing = groups[key] {
                let containsSensitiveData = existing.containsSensitiveData || item.containsSensitiveData
                let mergedRisk: RiskLevel = existing.risk == .review || item.risk == .review || containsSensitiveData
                    ? .review
                    : .high
                let mergedEvidence = Array(Set(existing.evidence + item.evidence)).sorted()
                groups[key] = AppResidue(
                    id: existing.id,
                    name: existing.name,
                    bundleHint: existing.bundleHint,
                    kind: existing.kind,
                    paths: existing.paths + item.paths,
                    confidence: min(existing.confidence, item.confidence),
                    risk: mergedRisk,
                    evidence: mergedEvidence,
                    containsSensitiveData: containsSensitiveData
                )
            } else {
                groups[key] = item
            }
        }
        return Array(groups.values)
    }

    static func mergeKey(_ raw: String) -> String {
        var base = raw.lowercased()
        for suffix in [".savedstate", ".plist", ".cookies", ".sqlite", ".db"] where base.hasSuffix(suffix) {
            base.removeLast(suffix.count)
            break
        }
        let parts = base.split(whereSeparator: { $0 == "." || $0 == "-" || $0 == "_" })
            .map(String.init)
            .filter { !["com", "org", "net", "io", "group", "app", "mac", "macos", "container"].contains($0) }
        return normalize(parts.isEmpty ? base : parts.joined())
    }

    private static func displayName(_ raw: String) -> String {
        if raw.hasSuffix(".savedState") {
            return raw.replacingOccurrences(of: ".savedState", with: "")
        }
        let parts = raw.split(separator: ".").map(String.init)
        if parts.count >= 3, let last = parts.last, last.count >= 3 {
            return last.replacingOccurrences(of: "-", with: " ").capitalized
        }
        return raw.replacingOccurrences(of: "_", with: " ")
    }

    private static func normalize(_ value: String) -> String {
        value.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .unicodeScalars
            .filter { CharacterSet.alphanumerics.contains($0) }
            .map(String.init)
            .joined()
            .lowercased()
    }

    private static func isUUIDName(_ value: String) -> Bool {
        UUID(uuidString: value) != nil
    }

    private static func modificationDate(_ url: URL) -> Date? {
        try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
    }

}
