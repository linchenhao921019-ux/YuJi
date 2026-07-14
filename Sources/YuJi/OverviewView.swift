import SwiftUI

struct OverviewView: View {
    @EnvironmentObject private var store: ScanStore

    private var cacheItems: [AppResidue] { store.cacheResults }
    private var trustedItems: [AppResidue] { store.residueResults.filter { $0.risk == .high } }
    private var reviewItems: [AppResidue] { store.residueResults.filter { $0.risk == .review } }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            if !store.hasStartedScan {
                ScanWelcomeView()
            } else if store.isScanning && store.results.isEmpty {
                ScanInProgressView()
            } else if store.visibleResults.isEmpty {
                EmptyState(
                    symbol: "checkmark.circle",
                    title: "没有发现需要处理的残留",
                    detail: "系统看起来很干净。你可以稍后重新扫描，或在设置中开启更多扫描位置。"
                )
                .surfacePanel()
            } else {
                SafetySummary()

                ScrollView {
                    LazyVStack(spacing: 14) {
                        if !cacheItems.isEmpty {
                            SafetyGroup(risk: .high, items: cacheItems, kind: .cache)
                        }
                        if !trustedItems.isEmpty {
                            SafetyGroup(risk: .high, items: trustedItems)
                        }
                        if !reviewItems.isEmpty {
                            SafetyGroup(risk: .review, items: reviewItems)
                        }
                    }
                    .padding(.vertical, 1)
                }

                CleanupBar()
            }
        }
        .padding(.horizontal, 26)
        .padding(.top, 6)
        .padding(.bottom, 20)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 6) {
                Text(pageTitle)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                if let date = store.history.first?.date ?? store.scanStartedAt {
                    Text("上次扫描：\(date.compactText)")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if store.inaccessibleLocations > 0 {
                Button { store.openFullDiskAccess() } label: {
                    Label("提升扫描完整度", systemImage: "lock.open")
                }
                .liquidButtonStyle()
            }
        }
    }

    private var pageTitle: String {
        if !store.hasStartedScan { return "清理卸载残留" }
        if store.isScanning { return "正在寻找卸载残留" }
        return "发现 \(store.visibleResults.count) 组残留与缓存"
    }
}

private struct ScanWelcomeView: View {
    @EnvironmentObject private var store: ScanStore

    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(YuJiTheme.accent.opacity(0.08))
                Circle()
                    .stroke(YuJiTheme.accent.opacity(0.28), lineWidth: 1.5)
                Image(systemName: "sparkle.magnifyingglass")
                    .font(.system(size: 42, weight: .medium))
                    .foregroundStyle(YuJiTheme.accent)
            }
            .frame(width: 108, height: 108)

            VStack(spacing: 9) {
                Text("查找卸载残留和应用缓存")
                    .font(.system(size: 23, weight: .semibold))
                Text("一次检查应用支持、偏好设置、日志、Web 数据与标准缓存。\n结果只保存在这台 Mac 上，任何清理都需要你确认。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }

            Button {
                store.startScan()
            } label: {
                Label("开始扫描", systemImage: "magnifyingglass")
                    .frame(minWidth: 132)
            }
            .liquidPrimaryButtonStyle()
            .tint(YuJiTheme.accent)
            .controlSize(.large)

            HStack(spacing: 8) {
                WelcomeFeature(symbol: "lock.shield", title: "本地扫描")
                WelcomeFeature(symbol: "bolt", title: "批量测量")
                WelcomeFeature(symbol: "arrow.uturn.backward", title: "可从废纸篓恢复")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .surfacePanel(radius: 20)
    }
}

private struct WelcomeFeature: View {
    let symbol: String
    let title: String

    var body: some View {
        Label(title, systemImage: symbol)
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.primary.opacity(0.045), in: Capsule())
    }
}

private struct ScanInProgressView: View {
    @State private var pulse = false

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle().stroke(YuJiTheme.accent.opacity(0.12), lineWidth: 10)
                Circle()
                    .trim(from: 0.08, to: 0.72)
                    .stroke(YuJiTheme.accent, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(pulse ? 360 : 0))
            }
            .frame(width: 104, height: 104)
            .animation(.linear(duration: 1.3).repeatForever(autoreverses: false), value: pulse)
            Text("正在建立应用清单并批量测量…")
                .font(.headline)
            Text("会跳过系统组件、私有容器与受保护数据。")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .surfacePanel()
        .onAppear { pulse = true }
    }
}

private struct SafetySummary: View {
    @EnvironmentObject private var store: ScanStore

    private var trustedSize: Int64 {
        store.visibleResults.filter { $0.risk == .high }.reduce(0) { $0 + $1.totalSize }
    }

    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 18) {
                ZStack {
                    Circle()
                        .fill(YuJiTheme.trusted.opacity(0.09))
                    Circle()
                        .stroke(YuJiTheme.accent.opacity(0.72), lineWidth: 1.5)
                    Image(systemName: "checkmark.shield")
                        .font(.system(size: 31, weight: .medium))
                        .foregroundStyle(YuJiTheme.trusted)
                }
                .frame(width: 76, height: 76)

                VStack(alignment: .leading, spacing: 6) {
                    Text("扫描完成，用时 \(durationText)")
                        .font(.system(size: 20, weight: .semibold))
                    Text("检查了 \(store.inspectedLocations.formatted()) 个位置 · \(store.protectedCandidates) 项敏感内容已标记")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider().frame(height: 72)
            SafetyMetric(symbol: "externaldrive", title: "可清理空间", value: store.totalSize.fileSizeText)
            Divider().frame(height: 72)
            SafetyMetric(symbol: "internaldrive", title: "应用缓存", value: store.cacheSize.fileSizeText)
            Divider().frame(height: 72)
            SafetyMetric(symbol: "trash", title: "卸载残留", value: store.residueResults.count.formatted())
        }
        .padding(.horizontal, 24)
        .frame(height: 126)
        .surfacePanel(radius: 18)
    }

    private var durationText: String {
        store.lastScanDuration < 1 ? "不到 1 秒" : String(format: "%.1f 秒", store.lastScanDuration)
    }
}

private struct SafetyMetric: View {
    let symbol: String
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Label(title, systemImage: symbol)
                .font(.callout)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 24, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(width: 150, alignment: .leading)
        .padding(.leading, 24)
    }
}

private struct SafetyGroup: View {
    @EnvironmentObject private var store: ScanStore
    let risk: RiskLevel
    let items: [AppResidue]
    var kind: CleanupKind = .residue

    private var totalSize: Int64 { items.reduce(0) { $0 + $1.totalSize } }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: groupSymbol)
                    .foregroundStyle(groupColor)
                    .font(.system(size: 16, weight: .semibold))
                    .padding(.top, 2)
                VStack(alignment: .leading, spacing: 3) {
                    Text(groupTitle)
                        .font(.system(size: 17, weight: .semibold))
                    Text(groupDetail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("共 \(items.count) 组，\(totalSize.fileSizeText)")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 13)

            Divider()

            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                ResidueRow(item: item, showsPath: true)
                if index < items.count - 1 { Divider().padding(.leading, 78) }
            }
        }
        .surfacePanel(radius: 16)
    }

    private var groupTitle: String { kind == .cache ? "应用缓存" : risk.sectionTitle }
    private var groupDetail: String {
        kind == .cache
            ? "来自标准缓存目录；清理后应用会按需重新生成。"
            : (risk == .review ? "这些项目会正常参与全选；清理前请留意风险提示。" : risk.sectionDetail)
    }
    private var groupSymbol: String {
        kind == .cache ? "internaldrive.fill" : (risk == .high ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
    }
    private var groupColor: Color {
        kind == .cache ? YuJiTheme.accent : (risk == .high ? YuJiTheme.trusted : YuJiTheme.review)
    }
}

struct ResultPanel: View {
    @EnvironmentObject private var store: ScanStore
    let items: [AppResidue]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button { store.selectAllVisible() } label: {
                    Image(systemName: allSelected ? "checkmark.square.fill" : "square")
                        .foregroundStyle(allSelected ? YuJiTheme.accent : .secondary)
                }
                .buttonStyle(.plain)
                Text("清理项目")
                Spacer()
                Text("占用空间").frame(width: 116, alignment: .leading)
                Text("判断").frame(width: 108, alignment: .leading)
                Color.clear.frame(width: 22)
            }
            .font(.callout)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 22)
            .frame(height: 42)

            Divider()
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                ResidueRow(item: item)
                if index < items.count - 1 { Divider().padding(.leading, 82) }
            }
        }
        .surfacePanel()
    }

    private var allSelected: Bool {
        !items.isEmpty && Set(items.map(\.id)).isSubset(of: store.selectedIDs)
    }
}

struct ResidueRow: View {
    @EnvironmentObject private var store: ScanStore
    @State private var hovering = false
    let item: AppResidue
    var showsPath = false

    var body: some View {
        HStack(spacing: 14) {
            Button { store.toggleSelection(item) } label: {
                Image(systemName: selectionSymbol)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(store.selectedIDs.contains(item.id) ? YuJiTheme.accent : .secondary)
                    .frame(width: 28, height: 34)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            ResidueIcon(name: item.name, size: 42)
            VStack(alignment: .leading, spacing: 3) {
                Text(item.name)
                    .font(.system(size: 16, weight: .medium))
                    .lineLimit(1)
                Text(metadata)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
            Text(item.displaySize)
                .foregroundStyle(.secondary)
                .frame(width: 116, alignment: .leading)
            Group {
                if item.kind == .cache {
                    CleanupKindBadge(kind: .cache)
                } else if item.containsEmptyDirectory {
                    Text("空文件夹")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.blue)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.1), in: Capsule())
                } else {
                    RiskBadge(risk: item.risk, confidence: item.confidence)
                }
            }
            .frame(width: 108, alignment: .leading)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 18)
        .frame(height: showsPath ? 74 : 70)
        .background(rowBackground)
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .onTapGesture { store.selectedResidue = item }
        .contextMenu {
            Button("在访达中显示") { item.paths.first.map { store.reveal($0.path) } }
            Button("加入白名单") { store.addToWhitelist(item) }
        }
    }

    private var metadata: String {
        let count = item.totalFiles > 0 ? "\(item.totalFiles.formatted()) 个文件" : "\(item.paths.count) 个关联目录"
        let prefix = item.kind == .cache ? "应用缓存" : "\(item.confidence)% 置信度"
        guard showsPath, let path = item.paths.first?.path else { return "\(count) · \(prefix)" }
        return "\(prefix)  ·  \(count)  ·  \(path)"
    }

    private var selectionSymbol: String {
        if store.selectedIDs.contains(item.id) { return "checkmark.square.fill" }
        return "square"
    }

    @ViewBuilder private var rowBackground: some View {
        if store.selectedIDs.contains(item.id) {
            YuJiTheme.accent.opacity(0.065)
        } else if hovering {
            Color.primary.opacity(0.035)
        } else {
            Color.clear
        }
    }
}

struct CleanupBar: View {
    @EnvironmentObject private var store: ScanStore

    var body: some View {
        HStack {
            Button {
                store.selectAllVisible()
            } label: {
                Label(
                    store.allVisibleSelected ? "取消全选" : "全选",
                    systemImage: store.allVisibleSelected ? "checkmark.square.fill" : "square"
                )
            }
            .liquidButtonStyle()
            .controlSize(.regular)
            .disabled(store.visibleResults.isEmpty)

            Divider()
                .frame(height: 30)

            VStack(alignment: .leading, spacing: 3) {
                Text("已选择 \(store.selectedResults.count) 组（\(store.selectedSize.fileSizeText)）")
                    .foregroundStyle(store.selectedIDs.isEmpty ? .secondary : .primary)
                Text("清理后可从系统废纸篓恢复")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(buttonTitle) { store.requestTrash() }
                .liquidPrimaryButtonStyle()
                .tint(YuJiTheme.accent)
                .controlSize(.large)
                .disabled(store.selectedIDs.isEmpty)
                .frame(minWidth: 240)
        }
        .padding(.horizontal, 20)
        .frame(height: 68)
        .glassPanel(radius: 16)
    }

    private var buttonTitle: String {
        store.selectedIDs.isEmpty ? "移到废纸篓" : "移到废纸篓 · \(store.selectedSize.fileSizeText)"
    }
}
