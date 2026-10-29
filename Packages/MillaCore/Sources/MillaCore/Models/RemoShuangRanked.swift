import Foundation

/// 热摸爽首页榜单（https://remoshuang.com/api/ranked）与「正在升温」
/// （https://remoshuang.com/api/trends/home）的响应模型。
///
/// 首页编号列表的顺序完全由接口 `position` 决定（站点就是按这个顺序渲染，
/// 热度也已是后端排好的结果），App 不再二次排序，保证与网页一致。
public enum RemoShuangRanked {

    public struct SourceRef: Codable, Sendable, Equatable {
        public let key: String
        public let name: String

        public init(key: String, name: String) {
            self.key = key
            self.name = name
        }
    }

    public struct Item: Codable, Sendable, Identifiable {
        public let position: Int
        public let id: String
        public let title: String
        public let url: String
        public let sourceName: String
        public let sourceCategory: String?
        public let heatValue: Double
        public let heatLabel: String
        public let sources: [SourceRef]

        public var sourceCount: Int { max(sources.count, 1) }
        public var link: URL? { URL(string: url) }

        public init(
            position: Int,
            id: String,
            title: String,
            url: String,
            sourceName: String,
            sourceCategory: String?,
            heatValue: Double,
            heatLabel: String,
            sources: [SourceRef]
        ) {
            self.position = position
            self.id = id
            self.title = title
            self.url = url
            self.sourceName = sourceName
            self.sourceCategory = sourceCategory
            self.heatValue = heatValue
            self.heatLabel = heatLabel
            self.sources = sources
        }
    }

    public struct Page: Decodable {
        public let page: Int
        public let totalPages: Int
        public let items: [Item]
    }

    private struct Envelope: Decodable { let data: Page }

    /// 解码一页榜单：{"data":{"page":1,"totalPages":10,"items":[...]}}。
    public static func decodePage(from data: Data) throws -> Page {
        try JSONDecoder().decode(Envelope.self, from: data).data
    }

    /// UI 直接展示的扁平条目（可持久化缓存）。
    public struct Entry: Codable, Sendable, Identifiable, Equatable {
        public let id: String
        public let title: String
        public let link: URL?
        /// 热度原文，如 "7803.1 万热度"。
        public let heat: String
        public let sourceName: String
        /// 报道该条目的来源数量（"等 N 个来源"）。
        public let sourceCount: Int

        public init(
            id: String,
            title: String,
            link: URL?,
            heat: String,
            sourceName: String,
            sourceCount: Int
        ) {
            self.id = id
            self.title = title
            self.link = link
            self.heat = heat
            self.sourceName = sourceName
            self.sourceCount = sourceCount
        }
    }

    /// 站点分类导航顺序（与网页顶部标签一致）。
    public static let siteCategoryOrder = [
        "科技", "AI", "财经", "新闻", "游戏", "娱乐", "社区", "发现机会",
        "阅读", "知识", "生活", "编程", "体育", "外国媒体", "健康", "设计", "教育"
    ]

    /// 分类导航：按站点顺序排列，只保留榜单里实际出现的分类。
    public static func categoryLabels(for items: [Item]) -> [String] {
        let present = Set(items.compactMap(\.sourceCategory).filter { !$0.isEmpty })
        let ordered = siteCategoryOrder.filter { present.contains($0) }
        let extras = present
            .subtracting(siteCategoryOrder)
            .subtracting(["其他"])
            .sorted()
        return ordered + extras
    }

    /// 组装条目：保持接口顺序（`position` 升序）。
    /// - `category == nil` → 综合榜，即网页头条下方从 1 开始的完整列表；
    /// - 指定分类 → 只保留该分类，顺序不变。
    public static func entries(from items: [Item], category: String?) -> [Entry] {
        items
            .filter { category == nil || $0.sourceCategory == category }
            .sorted { $0.position < $1.position }
            .map { item in
                Entry(
                    // 接口的 id 是榜单快照标识（如 "r1"），会跨条目重复，
                    // 叠加 position 才能保证 ForEach 的 id 唯一。
                    id: "\(item.id)#\(item.position)",
                    title: item.title,
                    link: item.link,
                    heat: item.heatLabel,
                    sourceName: item.sourceName,
                    sourceCount: item.sourceCount
                )
            }
    }

    // MARK: - 正在升温

    public struct Rising: Codable, Sendable, Identifiable, Equatable {
        public let eventId: String
        public let title: String
        public let url: String
        /// 升温速率：89.193 表示 ↑8919%。
        public let velocity: Double
        public let sourceCount: Int
        public let newSources: Int
        public let firstSeenAt: String?
        public let category: String?

        public var id: String { eventId }
        public var link: URL? { URL(string: url) }
        /// 展示用升温百分比，如 "8919%"。
        public var risePercent: Int { Int((velocity * 100).rounded()) }
        /// 首次出现时间（ISO8601，可能带毫秒）。
        public var firstSeenDate: Date? {
            guard let firstSeenAt else { return nil }
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            return formatter.date(from: firstSeenAt)
        }

        public init(
            eventId: String,
            title: String,
            url: String,
            velocity: Double,
            sourceCount: Int,
            newSources: Int,
            firstSeenAt: String?,
            category: String?
        ) {
            self.eventId = eventId
            self.title = title
            self.url = url
            self.velocity = velocity
            self.sourceCount = sourceCount
            self.newSources = newSources
            self.firstSeenAt = firstSeenAt
            self.category = category
        }
    }

    private struct TrendsEnvelope: Decodable {
        let available: Bool?
        let rising: [Rising]
    }

    /// 解码「正在升温」：{"available":true,"rising":[...]}。
    public static func decodeTrends(from data: Data) throws -> [Rising] {
        let envelope = try JSONDecoder().decode(TrendsEnvelope.self, from: data)
        return envelope.rising
    }
}
