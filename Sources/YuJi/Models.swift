import Foundation
import SwiftUI

enum RiskLevel: String, Codable, CaseIterable, Sendable {
    case high = "建议清理"
    case review = "需确认"

    var color: Color {
        switch self {
        case .high: .green
        case .review: .orange
        }
    }

    var explanation: String {
        switch self {
        case .high: "判断依据较充分，通常不影响现有应用或系统；清理后仍可从废纸篓恢复。"
        case .review: "可能包含个人数据或重要配置，请查看关联文件夹后再决定。"
        }
    }

    var sectionTitle: String {
        switch self {
        case .high: "建议清理（可信）"
        case .review: "需要你确认"
        }
    }

    var sectionDetail: String {
        switch self {
        case .high: "这些残留通常不影响应用或系统，可以放心检查。"
        case .review: "这些项目可能包含个人数据或重要配置，建议先确认内容。"
        }
    }
}

enum CleanupKind: String, Codable, CaseIterable, Sendable {
    case residue = "卸载残留"
    case cache = "应用缓存"

    var symbol: String {
        switch self {
        case .residue: "trash"
        case .cache: "internaldrive"
        }
    }
}

struct ResiduePath: Identifiable, Codable, Hashable, Sendable {
    var id: String { path }
    let path: String
    let size: Int64
    let fileCount: Int
    let modifiedAt: Date?
    var isEmptyDirectory: Bool = false
}

struct AppResidue: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let name: String
    let bundleHint: String
    let kind: CleanupKind
    var paths: [ResiduePath]
    let confidence: Int
    let risk: RiskLevel
    let evidence: [String]
    var containsSensitiveData: Bool = false

    var totalSize: Int64 { paths.reduce(0) { $0 + $1.size } }
    var totalFiles: Int { paths.reduce(0) { $0 + $1.fileCount } }
    var latestModification: Date? { paths.compactMap(\.modifiedAt).max() }
    var containsEmptyDirectory: Bool { paths.contains { $0.isEmptyDirectory } }
    var displaySize: String { containsEmptyDirectory && totalSize == 0 ? "空文件夹" : totalSize.fileSizeText }
}

struct ScanRecord: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let date: Date
    let resultCount: Int
    let totalSize: Int64
    let inaccessibleLocations: Int
}

enum AppSection: String, CaseIterable, Identifiable {
    case overview = "扫描概览"
    case residues = "残留与缓存"
    case largeFiles = "大型文件"
    case whitelist = "白名单"
    case history = "扫描历史"
    case settings = "设置"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .overview: "square.grid.2x2.fill"
        case .residues: "trash"
        case .largeFiles: "folder"
        case .whitelist: "checkmark.shield"
        case .history: "clock.arrow.circlepath"
        case .settings: "gearshape"
        }
    }
}

extension Int64 {
    var fileSizeText: String {
        ByteCountFormatter.string(fromByteCount: self, countStyle: .file)
    }
}

extension Date {
    var compactText: String {
        formatted(date: .abbreviated, time: .shortened)
    }
}
