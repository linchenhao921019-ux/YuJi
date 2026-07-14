import SwiftUI

struct ResidueListPage: View {
    @EnvironmentObject private var store: ScanStore

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("残留与缓存")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                Spacer()
                Picker("风险", selection: $store.riskFilter) {
                    Text("全部风险").tag(RiskLevel?.none)
                    ForEach(RiskLevel.allCases, id: \.self) { level in
                        Text(level.rawValue).tag(Optional(level))
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 130)
                Button {
                    store.showEmptyOnly.toggle()
                } label: {
                    Label("空文件夹", systemImage: "folder.badge.questionmark")
                }
                .buttonStyle(.bordered)
                .tint(store.showEmptyOnly ? YuJiTheme.accent : .gray)
            }

            if store.visibleResults.isEmpty {
                EmptyState(symbol: "checkmark.shield", title: "没有匹配的清理项目", detail: "尝试清除搜索条件或切换筛选。")
                    .glassPanel()
            } else {
                ScrollView {
                    ResultPanel(items: store.visibleResults)
                        .padding(.vertical, 1)
                }
                CleanupBar()
            }
        }
        .padding(.horizontal, 26)
        .padding(.top, 18)
        .padding(.bottom, 20)
    }
}

struct LargeFilesPage: View {
    @EnvironmentObject private var store: ScanStore

    private var largeItems: [AppResidue] {
        store.visibleResults.filter { !$0.containsEmptyDirectory && $0.totalSize >= 50 * 1024 * 1024 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("大型项目")
                .font(.system(size: 32, weight: .bold, design: .rounded))
            Text("显示超过 50 MB 的卸载残留和应用缓存。清理缓存前建议关闭相关应用。")
                .foregroundStyle(.secondary)
            if largeItems.isEmpty {
                EmptyState(symbol: "folder.badge.questionmark", title: "没有大型项目", detail: "当前扫描结果中没有超过 50 MB 的候选项目。")
                    .glassPanel()
            } else {
                ScrollView { ResultPanel(items: largeItems) }
                CleanupBar()
            }
        }
        .padding(.horizontal, 26)
        .padding(.top, 18)
        .padding(.bottom, 20)
    }
}

struct WhitelistPage: View {
    @EnvironmentObject private var store: ScanStore

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("白名单")
                .font(.system(size: 32, weight: .bold, design: .rounded))
            Text("白名单中的目录不会出现在扫描结果里。")
                .foregroundStyle(.secondary)
            if store.whitelist.isEmpty {
                EmptyState(symbol: "checkmark.shield", title: "白名单是空的", detail: "在残留项目的详情或右键菜单中，可以把需要保留的内容加入这里。")
                    .glassPanel()
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(store.whitelist).sorted(), id: \.self) { name in
                        HStack {
                            Image(systemName: "checkmark.shield.fill")
                                .foregroundStyle(.green)
                            Text(name)
                            Spacer()
                            Button("移除") { store.removeFromWhitelist(name) }
                        }
                        .padding(.horizontal, 20)
                        .frame(height: 54)
                        Divider().padding(.leading, 48)
                    }
                }
                .glassPanel()
                Spacer()
            }
        }
        .padding(.horizontal, 26)
        .padding(.top, 18)
        .padding(.bottom, 20)
    }
}

struct HistoryPage: View {
    @EnvironmentObject private var store: ScanStore

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("扫描历史")
                .font(.system(size: 32, weight: .bold, design: .rounded))
            if store.history.isEmpty {
                EmptyState(symbol: "clock.arrow.circlepath", title: "还没有扫描历史", detail: "完成第一次扫描后，结果摘要会保存在这里。")
                    .glassPanel()
            } else {
                VStack(spacing: 0) {
                    HStack {
                        Text("时间")
                        Spacer()
                        Text("发现项目").frame(width: 110, alignment: .leading)
                        Text("可检查空间").frame(width: 130, alignment: .leading)
                        Text("受限位置").frame(width: 90, alignment: .leading)
                    }
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 20)
                    .frame(height: 44)
                    Divider()
                    ForEach(store.history) { record in
                        HStack {
                            Image(systemName: "clock")
                                .foregroundStyle(.secondary)
                            Text(record.date.compactText)
                            Spacer()
                            Text("\(record.resultCount) 组").frame(width: 110, alignment: .leading)
                            Text(record.totalSize.fileSizeText).frame(width: 130, alignment: .leading)
                            Text("\(record.inaccessibleLocations)").frame(width: 90, alignment: .leading)
                        }
                        .padding(.horizontal, 20)
                        .frame(height: 56)
                        Divider().padding(.leading, 48)
                    }
                }
                .glassPanel()
                Spacer()
            }
        }
        .padding(.horizontal, 26)
        .padding(.top, 18)
        .padding(.bottom, 20)
    }
}

struct SettingsPage: View {
    @EnvironmentObject private var store: ScanStore

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("设置")
                .font(.system(size: 32, weight: .bold, design: .rounded))

            VStack(alignment: .leading, spacing: 14) {
                Label("扫描权限", systemImage: "lock.shield")
                    .font(.headline)
                Text("开启“完全磁盘访问”可以检查受系统隐私保护的位置。余迹不会上传文件名、路径或扫描结果。")
                    .foregroundStyle(.secondary)
                Button("打开完全磁盘访问设置…") { store.openFullDiskAccess() }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassPanel()

            VStack(alignment: .leading, spacing: 10) {
                Text("安全原则").font(.headline)
                Label("清理只会移到系统废纸篓", systemImage: "trash")
                Label("系统组件、符号链接与私有容器会被排除", systemImage: "checkmark.shield")
                Label("书签、登录信息、存档等个人数据会显示醒目提醒", systemImage: "exclamationmark.shield")
                Label("全选会选择当前列表的所有项目，风险提示不会代替你做决定", systemImage: "checklist")
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassPanel()
            Spacer()
        }
        .padding(.horizontal, 26)
        .padding(.top, 18)
        .padding(.bottom, 20)
    }
}
