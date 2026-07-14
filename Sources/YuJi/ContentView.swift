import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: ScanStore

    var body: some View {
        HStack(spacing: 0) {
            Sidebar()
                .frame(width: 252)
            Divider().opacity(0.36)
            VStack(spacing: 0) {
                TopBar()
                Group {
                    switch store.section {
                    case .overview: OverviewView()
                    case .residues: ResidueListPage()
                    case .largeFiles: LargeFilesPage()
                    case .whitelist: WhitelistPage()
                    case .history: HistoryPage()
                    case .settings: SettingsPage()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background {
            YuJiBackground()
        }
        .alert(item: $store.message) { message in
            Alert(title: Text(message.title), message: Text(message.detail), dismissButton: .default(Text("好")))
        }
        .confirmationDialog(
            "将所选项目移到废纸篓？",
            isPresented: $store.pendingTrash,
            titleVisibility: .visible
        ) {
            Button("移到废纸篓（\(store.selectedSize.fileSizeText)）", role: .destructive) {
                store.moveSelectedToTrash()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text(trashWarning)
        }
        .sheet(item: $store.selectedResidue) { residue in
            ResidueDetailSheet(residue: residue)
                .environmentObject(store)
        }
    }

    private var trashWarning: String {
        var notes = ["不会立即永久删除，需要时可以从废纸篓恢复。"]
        if store.selectedReviewCount > 0 {
            notes.append("包含 \(store.selectedReviewCount) 组“需确认”项目，请确认没有需要保留的配置或数据。")
        }
        if store.selectedSensitiveCount > 0 {
            notes.append("其中 \(store.selectedSensitiveCount) 组带有个人数据特征。")
        }
        if store.selectedCacheCount > 0 {
            notes.append("清理缓存前建议关闭相关应用。")
        }
        return notes.joined(separator: "\n")
    }
}

private struct Sidebar: View {
    @EnvironmentObject private var store: ScanStore

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(YuJiTheme.accent.gradient)
                    Image(systemName: "sparkles")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                }
                .frame(width: 40, height: 40)
                VStack(alignment: .leading, spacing: 1) {
                    Text("余迹")
                        .font(.system(size: 20, weight: .bold))
                    Text("安全清理")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 22)
            .padding(.top, 54)
            .padding(.bottom, 24)

            VStack(spacing: 5) {
                ForEach(AppSection.allCases.filter { $0 != .settings }) { section in
                    SidebarRow(section: section)
                }
            }
            .padding(.horizontal, 13)

            Spacer()

            SidebarRow(section: .settings)
                .padding(.horizontal, 13)
                .padding(.bottom, 22)
        }
        .background(.ultraThinMaterial)
    }

    private func SidebarRow(section: AppSection) -> some View {
        Button {
            withAnimation(.snappy(duration: 0.22)) { store.section = section }
        } label: {
            HStack(spacing: 13) {
                Image(systemName: section.symbol)
                    .font(.system(size: 17, weight: .medium))
                    .frame(width: 22)
                Text(section.rawValue)
                    .font(.system(size: 16, weight: store.section == section ? .semibold : .regular))
                Spacer()
                if section == .residues, !store.results.isEmpty {
                    Text("\(store.visibleResults.count)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .foregroundStyle(store.section == section ? YuJiTheme.accent : Color.primary.opacity(0.72))
            .padding(.horizontal, 14)
            .frame(height: 48)
            .background(store.section == section ? YuJiTheme.accent.opacity(0.12) : .clear, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct TopBar: View {
    @EnvironmentObject private var store: ScanStore

    var body: some View {
        HStack(spacing: 10) {
            if store.hasStartedScan {
                HStack(spacing: 7) {
                    Circle()
                        .fill(store.isScanning ? YuJiTheme.accent : YuJiTheme.trusted)
                        .frame(width: 7, height: 7)
                    Text(store.isScanning ? "扫描进行中" : "安全扫描已完成")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 11)
                .padding(.vertical, 7)
                .background(Color.primary.opacity(0.045), in: Capsule())
            }
            Spacer()
            if store.section == .residues || (store.section == .overview && store.hasStartedScan) {
                HStack(spacing: 7) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.tertiary)
                    TextField("搜索应用或路径", text: $store.searchText)
                        .textFieldStyle(.plain)
                    if !store.searchText.isEmpty {
                        Button { store.searchText = "" } label: {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 11)
                .frame(width: 248, height: 34)
                .background(Color.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            if store.hasStartedScan {
                Button {
                    store.startScan()
                } label: {
                    HStack(spacing: 8) {
                        if store.isScanning { ProgressView().controlSize(.small) }
                        else { Image(systemName: "arrow.clockwise") }
                        Text(store.isScanning ? "正在扫描" : "重新扫描")
                    }
                }
                .liquidButtonStyle()
                .controlSize(.large)
                .disabled(store.isScanning)
            }

            Menu {
                Button("导出扫描报告…") { store.exportReport() }
                Button("完全磁盘访问…") { store.openFullDiskAccess() }
            } label: {
                Image(systemName: "ellipsis")
                    .frame(width: 24, height: 24)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
        .buttonStyle(.borderless)
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .frame(height: 60)
    }
}
