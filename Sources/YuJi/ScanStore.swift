import AppKit
import Foundation
import SwiftUI

@MainActor
final class ScanStore: ObservableObject {
    @Published var section: AppSection = .overview
    @Published var results: [AppResidue] = []
    @Published var selectedIDs = Set<UUID>()
    @Published var selectedResidue: AppResidue?
    @Published var isScanning = false
    @Published var hasStartedScan = false
    @Published var scanStartedAt: Date?
    @Published var inaccessibleLocations = 0
    @Published var inspectedLocations = 0
    @Published var protectedCandidates = 0
    @Published var lastScanDuration: TimeInterval = 0
    @Published var searchText = ""
    @Published var riskFilter: RiskLevel?
    @Published var showEmptyOnly = false
    @Published var whitelist = Set<String>()
    @Published var history: [ScanRecord] = []
    @Published var message: AppMessage?
    @Published var pendingTrash = false

    private let whitelistKey = "YuJi.whitelist"
    private let historyKey = "YuJi.history"

    init() {
        loadPersistedData()
        if ProcessInfo.processInfo.environment["YUJI_DEMO"] == "1" {
            results = Self.previewResults
            hasStartedScan = true
        }
    }

    var visibleResults: [AppResidue] {
        results.filter { item in
            !whitelist.contains(item.bundleHint) &&
            (riskFilter == nil || item.risk == riskFilter) &&
            (!showEmptyOnly || item.containsEmptyDirectory) &&
            (searchText.isEmpty || item.name.localizedCaseInsensitiveContains(searchText) || item.paths.contains { $0.path.localizedCaseInsensitiveContains(searchText) })
        }
    }

    var selectedResults: [AppResidue] {
        results.filter { selectedIDs.contains($0.id) }
    }

    var eligibleVisibleResults: [AppResidue] {
        visibleResults
    }

    var selectedSize: Int64 { selectedResults.reduce(0) { $0 + $1.totalSize } }
    var totalSize: Int64 { visibleResults.reduce(0) { $0 + $1.totalSize } }
    var totalFiles: Int { visibleResults.reduce(0) { $0 + $1.totalFiles } }
    var cacheResults: [AppResidue] { visibleResults.filter { $0.kind == .cache } }
    var residueResults: [AppResidue] { visibleResults.filter { $0.kind == .residue } }
    var cacheSize: Int64 { cacheResults.reduce(0) { $0 + $1.totalSize } }
    var selectedCacheCount: Int { selectedResults.filter { $0.kind == .cache }.count }
    var selectedReviewCount: Int { selectedResults.filter { $0.risk == .review }.count }
    var selectedSensitiveCount: Int { selectedResults.filter(\.containsSensitiveData).count }
    var allVisibleSelected: Bool {
        let visibleIDs = Set(eligibleVisibleResults.map(\.id))
        return !visibleIDs.isEmpty && visibleIDs.isSubset(of: selectedIDs)
    }
    var highConfidenceCount: Int { visibleResults.filter { $0.risk == .high }.count }
    var emptyFolderCount: Int { visibleResults.reduce(0) { $0 + $1.paths.filter(\.isEmptyDirectory).count } }

    func startScan() {
        guard !isScanning else { return }
        hasStartedScan = true
        isScanning = true
        scanStartedAt = Date()
        selectedIDs.removeAll()

        Task {
            let output = await Task.detached(priority: .userInitiated) {
                ResidueScanner.scan()
            }.value
            results = output.results
            inaccessibleLocations = output.inaccessibleLocations
            inspectedLocations = output.inspectedLocations
            protectedCandidates = output.protectedCandidates
            lastScanDuration = output.duration
            // Never preselect cleanup targets. Confidence is guidance, not consent.
            selectedIDs.removeAll()
            isScanning = false

            let record = ScanRecord(
                id: UUID(),
                date: Date(),
                resultCount: output.results.count,
                totalSize: output.results.reduce(0) { $0 + $1.totalSize },
                inaccessibleLocations: output.inaccessibleLocations
            )
            history.insert(record, at: 0)
            history = Array(history.prefix(30))
            saveHistory()
        }
    }

    func toggleSelection(_ item: AppResidue) {
        if selectedIDs.contains(item.id) { selectedIDs.remove(item.id) }
        else { selectedIDs.insert(item.id) }
    }

    func selectAllVisible() {
        let ids = Set(eligibleVisibleResults.map(\.id))
        if ids.isSubset(of: selectedIDs) { selectedIDs.subtract(ids) }
        else { selectedIDs.formUnion(ids) }
    }

    func addToWhitelist(_ item: AppResidue) {
        whitelist.insert(item.bundleHint)
        selectedIDs.remove(item.id)
        saveWhitelist()
        selectedResidue = nil
        message = AppMessage(title: "已加入白名单", detail: "以后扫描会忽略“\(item.name)”。")
    }

    func removeFromWhitelist(_ name: String) {
        whitelist.remove(name)
        saveWhitelist()
    }

    func requestTrash() {
        guard !selectedResults.isEmpty else {
            message = AppMessage(title: "尚未选择项目", detail: "请先勾选需要清理的残留或缓存。")
            return
        }
        pendingTrash = true
    }

    func moveSelectedToTrash() {
        let targets = selectedResults
        pendingTrash = false
        var moved = 0
        var failures: [String] = []
        var policyBlocks = 0
        var operationFailures = 0

        for residue in targets {
            var itemMoved = false
            for path in residue.paths {
                let url = URL(fileURLWithPath: path.path)
                guard FileManager.default.fileExists(atPath: url.path) else { continue }
                let approvedLocation = residue.kind == .cache
                    ? SafetyPolicy.isApprovedUserCachePath(url.path)
                    : SafetyPolicy.isApprovedResiduePath(url.path)
                guard approvedLocation else {
                    policyBlocks += 1
                    failures.append("\(residue.name)：路径不在允许的安全清理范围，已阻止清理")
                    continue
                }
                guard !SafetyPolicy.isProtectedPath(url.path) else {
                    policyBlocks += 1
                    failures.append("\(residue.name)：系统保护目录，已阻止清理")
                    continue
                }
                do {
                    var resultingURL: NSURL?
                    try FileManager.default.trashItem(at: url, resultingItemURL: &resultingURL)
                    itemMoved = true
                } catch {
                    operationFailures += 1
                    failures.append("\(residue.name)：macOS 未允许移动“\(url.lastPathComponent)”，文件保持原位")
                }
            }
            if itemMoved { moved += 1 }
        }

        let movedIDs = Set(targets.map(\.id))
        results.removeAll { movedIDs.contains($0.id) && !$0.paths.contains { FileManager.default.fileExists(atPath: $0.path) } }
        selectedIDs.subtract(movedIDs)

        if failures.isEmpty {
            message = AppMessage(title: "已移到废纸篓", detail: "已安全移动 \(moved) 组项目，需要时可从废纸篓恢复。缓存会由相关应用按需重新生成。")
        } else if moved == 0 && policyBlocks > 0 && operationFailures == 0 {
            message = AppMessage(title: "已阻止不安全清理", detail: failures.prefix(3).joined(separator: "\n"))
        } else if moved == 0 {
            message = AppMessage(title: "所选项目未能移动", detail: failures.prefix(3).joined(separator: "\n"))
        } else {
            message = AppMessage(title: "部分项目未能移动", detail: failures.prefix(3).joined(separator: "\n"))
        }
    }

    func reveal(_ path: String) {
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
    }

    func openFullDiskAccess() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
            NSWorkspace.shared.open(url)
        }
    }

    func exportReport() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.nameFieldStringValue = "余迹扫描报告-\(Date().formatted(.iso8601.year().month().day())).csv"
        guard panel.runModal() == .OK, let url = panel.url else { return }

        let header = "应用,类型,判断,置信度,大小,文件数,最后修改,路径\n"
        let rows = visibleResults.map { item in
            let modified = item.latestModification?.formatted(.iso8601) ?? ""
            let paths = item.paths.map(\.path).joined(separator: " | ").replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(item.name)\",\(item.kind.rawValue),\(item.risk.rawValue),\(item.confidence),\(item.totalSize),\(item.totalFiles),\(modified),\"\(paths)\""
        }.joined(separator: "\n")
        do {
            try (header + rows).write(to: url, atomically: true, encoding: .utf8)
            message = AppMessage(title: "报告已导出", detail: url.path)
        } catch {
            message = AppMessage(title: "导出失败", detail: error.localizedDescription)
        }
    }

    private func loadPersistedData() {
        whitelist = Set(UserDefaults.standard.stringArray(forKey: whitelistKey) ?? [])
        if let data = UserDefaults.standard.data(forKey: historyKey),
           let decoded = try? JSONDecoder().decode([ScanRecord].self, from: data) {
            history = decoded
        }
    }

    private func saveWhitelist() {
        UserDefaults.standard.set(Array(whitelist).sorted(), forKey: whitelistKey)
    }

    private func saveHistory() {
        if let data = try? JSONEncoder().encode(history) {
            UserDefaults.standard.set(data, forKey: historyKey)
        }
    }

    private static let previewResults: [AppResidue] = [
        preview("Arc", "company.thebrowser.Browser", 318_400_000, 95, .high, "~/Library/Caches/company.thebrowser.Browser", kind: .cache),
        preview("Spacedrive", "spacedrive", 226_300_000, 96, .high, "~/Library/Application Support/spacedrive"),
        preview("Telegram", "ru.keepcoder.Telegram", 139_500_000, 78, .review, "~/Library/Group Containers/6N38VWS5BX.ru.keepcoder.Telegram"),
        preview("QQ浏览器", "QQBrowser3", 52_900_000, 75, .review, "~/Library/Application Support/QQBrowser3"),
        preview("AquaClip", "AquaClip", 41_200_000, 73, .review, "~/Library/Application Support/AquaClip"),
        preview("Postman", "Postman", 18_400_000, 70, .review, "~/Library/Application Support/Postman")
    ]

    private static func preview(_ name: String, _ hint: String, _ size: Int64, _ confidence: Int, _ risk: RiskLevel, _ path: String, kind: CleanupKind = .residue) -> AppResidue {
        AppResidue(
            id: UUID(),
            name: name,
            bundleHint: hint,
            kind: kind,
            paths: [ResiduePath(path: path, size: size, fileCount: 0, modifiedAt: Date().addingTimeInterval(-8_000_000))],
            confidence: confidence,
            risk: risk,
            evidence: kind == .cache
                ? ["位于当前用户的标准缓存目录", "删除后应用会在需要时重新生成缓存"]
                : ["未在常见位置找到对应应用", "目录超过三个月未更新"]
        )
    }
}

struct AppMessage: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
}
