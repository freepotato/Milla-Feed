import Foundation
import Observation
import MillaCore

/// 文章详情状态：已读标记与收藏切换。
@MainActor
@Observable
final class ArticleViewModel {

    let ranked: RankedFeedItem
    private(set) var isFavorite: Bool
    private(set) var isRead: Bool

    init(ranked: RankedFeedItem) {
        self.ranked = ranked
        self.isFavorite = false
        self.isRead = false
    }

    func onAppear(repository: FeedRepository) {
        repository.markRead(identifier: ranked.id)
        isRead = true
        isFavorite = repository.isFavorite(identifier: ranked.id)
    }

    func toggleFavorite(repository: FeedRepository) {
        isFavorite.toggle()
        repository.setFavorite(identifier: ranked.id, isFavorite: isFavorite)
    }
}
