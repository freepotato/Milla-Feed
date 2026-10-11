import Foundation
import SwiftData
import MillaCore

/// 文章的 SwiftData 持久化模型。
/// `shown == true` 表示已进入去重池；阅读/收藏状态同样在此维护。
@Model
final class StoredFeedArticle {

    /// 与核心库 `FeedItem.id` 一致的稳定内容标识。
    @Attribute(.unique) var identifier: String

    var source: StoredFeedSource?
    var title: String
    var linkString: String?
    var summary: String
    var contentHTML: String
    var imageURLString: String?
    var author: String?
    var publishedAt: Date?
    var isRead: Bool
    var isFavorite: Bool
    var shown: Bool
    var storedAt: Date

    init(
        identifier: String,
        source: StoredFeedSource?,
        title: String,
        linkString: String?,
        summary: String,
        contentHTML: String,
        imageURLString: String?,
        author: String?,
        publishedAt: Date?,
        isRead: Bool = false,
        isFavorite: Bool = false,
        shown: Bool = false,
        storedAt: Date = Date()
    ) {
        self.identifier = identifier
        self.source = source
        self.title = title
        self.linkString = linkString
        self.summary = summary
        self.contentHTML = contentHTML
        self.imageURLString = imageURLString
        self.author = author
        self.publishedAt = publishedAt
        self.isRead = isRead
        self.isFavorite = isFavorite
        self.shown = shown
        self.storedAt = storedAt
    }

    convenience init(_ item: FeedItem, source: StoredFeedSource?) {
        self.init(
            identifier: item.id,
            source: source,
            title: item.title,
            linkString: item.link?.absoluteString,
            summary: item.summary,
            contentHTML: item.contentHTML,
            imageURLString: item.imageURL?.absoluteString,
            author: item.author,
            publishedAt: item.publishedAt
        )
    }

    var link: URL? {
        linkString.flatMap(URL.init(string:))
    }

    func makeCoreItem() -> FeedItem {
        FeedItem(
            id: identifier,
            sourceID: source?.uuid ?? UUID(uuidString: "00000000-0000-0000-0000-000000000000")!,
            title: title,
            link: link,
            summary: summary,
            contentHTML: contentHTML,
            imageURL: imageURLString.flatMap(URL.init(string:)),
            author: author,
            publishedAt: publishedAt
        )
    }
}
