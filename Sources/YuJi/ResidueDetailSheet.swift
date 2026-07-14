import SwiftUI

struct ResidueDetailSheet: View {
    @EnvironmentObject private var store: ScanStore
    @Environment(\.dismiss) private var dismiss
    let residue: AppResidue

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 16) {
                ResidueIcon(name: residue.name, size: 58)
                VStack(alignment: .leading, spacing: 6) {
                    Text(residue.name).font(.title2.weight(.semibold))
                    if residue.kind == .cache {
                        CleanupKindBadge(kind: .cache)
                    } else {
                        RiskBadge(risk: residue.risk, confidence: residue.confidence, showConfidence: true)
                    }
                }
                Spacer()
                Button { dismiss() } label: { Image(systemName: "xmark.circle.fill") }
                    .buttonStyle(.plain)
                    .font(.title2)
                    .foregroundStyle(.tertiary)
            }
            .padding(24)

            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    if residue.containsSensitiveData {
                        Label {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("请留意：可能包含个人数据")
                                    .font(.headline)
                                Text("该提示不会阻止选择或清理；建议先在访达中确认内容。")
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "lock.shield.fill")
                                .font(.title2)
                                .foregroundStyle(YuJiTheme.review)
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(YuJiTheme.review.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }

                    DetailSection(title: "判断依据") {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(residue.evidence, id: \.self) { evidence in
                                Label(evidence, systemImage: "checkmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            Text(residue.kind == .cache
                                ? "缓存通常可以安全重新生成；清理前建议关闭相关应用。"
                                : residue.risk.explanation)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                    }

                    DetailSection(title: "\(residue.kind == .cache ? "缓存位置" : "关联文件夹")（\(residue.paths.count)）") {
                        VStack(spacing: 0) {
                            ForEach(residue.paths) { path in
                                HStack(spacing: 10) {
                                    Image(systemName: "folder.fill").foregroundStyle(.blue)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(path.path)
                                            .font(.system(.callout, design: .monospaced))
                                            .lineLimit(2)
                                        Text(path.fileCount > 0 ? "\(path.size.fileSizeText) · \(path.fileCount) 个文件" : path.size.fileSizeText)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Button { store.reveal(path.path) } label: {
                                        Image(systemName: "arrow.forward.square")
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.vertical, 10)
                                Divider()
                            }
                        }
                    }

                    DetailSection(title: "信息") {
                        Grid(alignment: .leading, horizontalSpacing: 22, verticalSpacing: 9) {
                            GridRow { Text("类型").foregroundStyle(.secondary); Text(residue.kind.rawValue) }
                            GridRow { Text("可回收空间").foregroundStyle(.secondary); Text(residue.displaySize) }
                            GridRow { Text("关联位置").foregroundStyle(.secondary); Text("\(residue.paths.count) 个") }
                            GridRow { Text("最后修改").foregroundStyle(.secondary); Text(residue.latestModification?.compactText ?? "未知") }
                            GridRow { Text("恢复方式").foregroundStyle(.secondary); Text("从系统废纸篓恢复") }
                        }
                    }
                }
                .padding(24)
            }

            Divider()
            HStack {
                Button("加入白名单") { store.addToWhitelist(residue) }
                Spacer()
                Button("取消") { dismiss() }
                if residue.containsSensitiveData {
                    Button("在访达中检查") { residue.paths.first.map { store.reveal($0.path) } }
                        .liquidButtonStyle()
                }
                Button("选择并返回") {
                    if !store.selectedIDs.contains(residue.id) {
                        store.toggleSelection(residue)
                    }
                    dismiss()
                }
                .liquidPrimaryButtonStyle()
            }
            .padding(18)
        }
        .frame(width: 650, height: 680)
        .background(.regularMaterial)
    }
}

private struct DetailSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.headline)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
