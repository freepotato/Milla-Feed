import SwiftUI
import Observation
import MillaCore

/// 历史文章：信息流只展示最新的 30 条，其余数据保留并按日期归档在这里。
struct HistoryView: View {

    @Environment(FeedRepository.self) private var repository

    @State private var viewModel = HistoryViewModel()

    var body: some View {
        ScrollView {
            if viewModel.sections.isEmpty {
                EmptyStateView(
                    systemImage: "archivebox",
                    title: "还没有归档文章",
                    message: "信息流只展示最新的 \(HomeViewModel.timelineLimit) 条，更早的文章会按日期归档在这里。"
                )
                .padding(.top, 60)
            } else {
                LazyVStack(alignment: .leading, spacing: AppSpacing.stackVertical) {
                    ForEach(viewModel.sections) { section in
                        dayHeader(section)
                        ForEach(section.items) { ranked in
                            NavigationLink {
                                ArticleView(ranked: ranked)
                            } label: {
                                FeedCardView(
                                    ranked: ranked,
                                    sourceTitle: viewModel.sourceTitles[ranked.sourceID] ?? "未知来源",
                                    isRead: viewModel.readIDs.contains(ranked.id)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.bottom, 24)
            }
        }
        .background(AppColors.screenBackground)
        .navigationTitle("历史文章")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.load(repository: repository)
        }
    }

    private func dayHeader(_ section: HistoryViewModel.DaySection) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(section.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppColors.secondaryText)
            Text("\(section.items.count) 篇")
                .font(.caption)
                .foregroundStyle(AppColors.tertiaryText)
            Spacer()
        }
        .padding(.horizontal, AppSpacing.screenHorizontal)
        .padding(.top, 4)
    }
}

/// 归档文章的日期分组。
@MainActor
@Observable
final class HistoryViewModel {

    struct DaySection: Identifiable {
        let day: Date?
        let title: String
        let items: [RankedFeedItem]
        var id: String { day.map { String($0.timeIntervalSince1970) } ?? "undated" }
    }

    private(set) var sections: [DaySection] = []
    private(set) var sourceTitles: [UUID: String] = [:]
    private(set) var readIDs: Set<String> = []

    func load(repository: FeedRepository) {
        let data = repository.loadArchiveData(limit: HomeViewModel.timelineLimit)
        sourceTitles = data.sourceTitles
        readIDs = data.readIDs

        let calendar = Calendar.current
        var byDay: [Date: [FeedItem]] = [:]
        var undated: [FeedItem] = []
        for item in data.items {
            if let publishedAt = item.publishedAt {
                byDay[calendar.startOfDay(for: publishedAt), default: []].append(item)
            } else {
                undated.append(item)
            }
        }

        var result: [DaySection] = byDay.keys.sorted(by: >).map { day in
            DaySection(day: day, title: Self.title(for: day), items: byDay[day, default: []].map(ranked))
        }
        if !undated.isEmpty {
            result.append(DaySection(day: nil, title: "日期未知", items: undated.map(ranked)))
        }
        sections = result
    }

    private func ranked(_ item: FeedItem) -> RankedFeedItem {
        RankedFeedItem(
            item: item,
            sourceID: item.sourceID,
            qualityScore: 0,
            recencyScore: 0,
            score: 0
        )
    }

    private static func title(for day: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(day) { return "今天" }
        if calendar.isDateInYesterday(day) { return "昨天" }

        let sameYear = calendar.component(.year, from: day) == calendar.component(.year, from: Date())
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateFormat = sameYear ? "M月d日" : "yyyy年M月d日"
        return formatter.string(from: day)
    }
}

#Preview("历史文章") {
    NavigationStack {
        HistoryView()
    }
    .environment(try! FeedRepository(inMemory: true))
    .environment(AppSettings())
}
