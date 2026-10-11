import Foundation
import SwiftData
import MillaCore

/// 订阅源的 SwiftData 持久化模型，与核心库的值类型 `FeedSource` 双向映射。
@Model
final class StoredFeedSource {

    @Attribute(.unique) var uuid: UUID
    var title: String
    var urlString: String
    var isEnabled: Bool
    var dailyLimit: Int
    var sampleSize: Int
    var qualityScore: Double
    var addedAt: Date
    var lastFetchedAt: Date?

    @Relationship(deleteRule: .cascade, inverse: \StoredFeedArticle.source)
    var articles: [StoredFeedArticle] = []

    init(
        uuid: UUID = UUID(),
        title: String,
        urlString: String,
        isEnabled: Bool = true,
        dailyLimit: Int = 10,
        sampleSize: Int = 5,
        qualityScore: Double = 0.8,
        addedAt: Date = Date(),
        lastFetchedAt: Date? = nil
    ) {
        self.uuid = uuid
        self.title = title
        self.urlString = urlString
        self.isEnabled = isEnabled
        self.dailyLimit = dailyLimit
        self.sampleSize = sampleSize
        self.qualityScore = qualityScore
        self.addedAt = addedAt
        self.lastFetchedAt = lastFetchedAt
    }

    convenience init(_ source: FeedSource) {
        self.init(
            uuid: source.id,
            title: source.title,
            urlString: source.url.absoluteString,
            isEnabled: source.isEnabled,
            dailyLimit: source.dailyLimit,
            sampleSize: source.sampleSize,
            qualityScore: source.qualityScore,
            addedAt: source.addedAt,
            lastFetchedAt: source.lastFetchedAt
        )
    }

    var url: URL? { URL(string: urlString) }

    func makeCoreSource() -> FeedSource {
        FeedSource(
            id: uuid,
            title: title,
            url: url ?? URL(string: "about:blank")!,
            isEnabled: isEnabled,
            dailyLimit: dailyLimit,
            sampleSize: sampleSize,
            qualityScore: qualityScore,
            addedAt: addedAt,
            lastFetchedAt: lastFetchedAt
        )
    }

    func update(from source: FeedSource) {
        title = source.title
        urlString = source.url.absoluteString
        isEnabled = source.isEnabled
        dailyLimit = source.dailyLimit
        sampleSize = source.sampleSize
        qualityScore = source.qualityScore
    }
}
