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
    /// 筛选侧重（SourceFocus.rawValue），旧数据缺省视为 balanced。
    var focusRaw: String?
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
        focus: SourceFocus = .balanced,
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
        self.focusRaw = focus.rawValue
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
            focus: source.focus,
            addedAt: source.addedAt,
            lastFetchedAt: source.lastFetchedAt
        )
    }

    var url: URL? { URL(string: urlString) }

    /// 筛选侧重；旧数据 focusRaw 为 nil 时按均衡处理。
    var focus: SourceFocus {
        get { focusRaw.flatMap(SourceFocus.init(rawValue:)) ?? .balanced }
        set { focusRaw = newValue.rawValue }
    }

    func makeCoreSource() -> FeedSource {
        FeedSource(
            id: uuid,
            title: title,
            url: url ?? URL(string: "about:blank")!,
            isEnabled: isEnabled,
            dailyLimit: dailyLimit,
            sampleSize: sampleSize,
            qualityScore: qualityScore,
            focus: focus,
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
        focusRaw = source.focus.rawValue
    }
}
