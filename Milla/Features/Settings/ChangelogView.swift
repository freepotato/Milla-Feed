import SwiftUI

/// 更新日志：读取随 App 打包的 docs/CHANGELOG.md（面向用户的精简版本说明）。
struct ChangelogView: View {

    @Environment(\.dismiss) private var dismiss

    private let entries = ChangelogDocument.load()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text("v\(entry.version)")
                                    .font(.headline)
                                    .foregroundStyle(AppColors.primaryText)
                                if !entry.date.isEmpty {
                                    Text(entry.date)
                                        .font(.caption)
                                        .foregroundStyle(AppColors.tertiaryText)
                                }
                                Spacer()
                                if index == 0 {
                                    Text("最新版本")
                                        .font(.caption2.weight(.medium))
                                        .foregroundStyle(AppColors.brand)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(AppColors.brand.opacity(0.12))
                                        .clipShape(Capsule())
                                }
                            }

                            ForEach(Array(entry.items.enumerated()), id: \.offset) { _, item in
                                HStack(alignment: .top, spacing: 8) {
                                    Circle()
                                        .fill(AppColors.brand.opacity(0.5))
                                        .frame(width: 5, height: 5)
                                        .padding(.top, 7)
                                    Text(item)
                                        .font(.subheadline)
                                        .foregroundStyle(AppColors.secondaryText)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppColors.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }
                .padding(AppSpacing.screenHorizontal)
            }
            .background(AppColors.screenBackground)
            .navigationTitle("更新日志")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }
}

// MARK: - 文档解析

private struct ChangelogDocument {

    struct Entry: Identifiable {
        let version: String
        let date: String
        let items: [String]
        var id: String { version }
    }

    static func load() -> [Entry] {
        guard
            let url = Bundle.main.url(forResource: "CHANGELOG", withExtension: "md"),
            let text = try? String(contentsOf: url, encoding: .utf8)
        else { return [] }

        var entries: [Entry] = []
        var version = ""
        var date = ""
        var items: [String] = []

        func flush() {
            guard !version.isEmpty else { return }
            entries.append(Entry(version: version, date: date, items: items))
        }

        for rawLine in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("## ") {
                flush()
                let heading = line.dropFirst(3)
                let parts = heading.split(separator: "·", omittingEmptySubsequences: false)
                version = parts.first?.trimmingCharacters(in: .whitespaces) ?? ""
                date = parts.count > 1
                    ? parts[1].trimmingCharacters(in: .whitespaces)
                    : ""
                items = []
            } else if line.hasPrefix("- ") {
                items.append(String(line.dropFirst(2)))
            }
        }
        flush()
        return entries
    }
}
