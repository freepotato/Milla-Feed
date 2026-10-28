import SwiftUI
import MillaCore

/// 收藏列表：所有星标文章，按发布时间倒序；数据在 SwiftData，随收藏实时更新。
struct FavoritesListView: View {

    @Environment(FeedRepository.self) private var repository
    @Environment(AppRouter.self) private var router

    @State private var items: [RankedFeedItem] = []
    @State private var sourceTitles: [UUID: String] = [:]
    @State private var readIDs: Set<String> = []

    var body: some View {
        ScrollView {
            LazyVStack(spacing: AppSpacing.stackVertical) {
                if items.isEmpty {
                    EmptyStateView(
                        systemImage: "star",
                        title: "还没有收藏",
                        message: "在文章详情页点右上角星标即可收藏。"
                    ) {}
                    .padding(.top, 80)
                } else {
                    ForEach(items) { ranked in
                        Button {
                            router.path.append(.article(ranked))
                        } label: {
                            FeedCardView(
                                ranked: ranked,
                                sourceTitle: sourceTitles[ranked.sourceID] ?? "未知来源",
                                isRead: readIDs.contains(ranked.id)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.vertical, 16)
        }
        .background(AppColors.screenBackground)
        .navigationTitle("收藏")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: reload)
    }

    private func reload() {
        items = repository.favoriteItems().map {
            RankedFeedItem(item: $0, sourceID: $0.sourceID, qualityScore: 0, recencyScore: 0, score: 0)
        }
        sourceTitles = Dictionary(
            uniqueKeysWithValues: repository.allStoredSources().map { ($0.uuid, $0.title) }
        )
        readIDs = repository.loadHomeData().readIDs
    }
}
