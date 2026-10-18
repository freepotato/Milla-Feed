import Foundation

/// 热摸爽「今日大事」接口（https://remoshuang.com/api/news/today）的响应模型。
///
/// 响应里 `top` 是"今天最值得关注的 10 件事"，`sections` 是各分类板块；
/// 一次抓取即拿到全部分类，App 层按时段缓存整份数据。
public struct RemoShuangToday: Codable, Sendable {

    public struct Event: Codable, Sendable, Identifiable {
        /// 事件稳定标识（如 "2026-10-19:hot-10"）。
        public let eventId: String
        public let title: String
        public let summary: String
        /// 分类中文名（如 "科技"）。
        public let category: String
        /// 参与报道的来源数。
        public let sourceCount: Int
        public let sourceNames: [String]
        /// 站内路径（如 "/event/20261019-56ba51e9"）。
        public let href: String

        public var id: String { eventId }

        /// 事件详情页完整地址。
        public var eventURL: URL? {
            URL(string: "https://remoshuang.com" + href)
        }

        public init(
            eventId: String,
            title: String,
            summary: String,
            category: String,
            sourceCount: Int,
            sourceNames: [String],
            href: String
        ) {
            self.eventId = eventId
            self.title = title
            self.summary = summary
            self.category = category
            self.sourceCount = sourceCount
            self.sourceNames = sourceNames
            self.href = href
        }
    }

    public struct Section: Codable, Sendable, Identifiable {
        /// 分类键（如 "tech"）。
        public let key: String
        /// 分类中文名（如 "科技"）。
        public let label: String
        public let items: [Event]

        public var id: String { key }

        public init(key: String, label: String, items: [Event]) {
            self.key = key
            self.label = label
            self.items = items
        }
    }

    /// 榜单日期（如 "2026-10-18"）。
    public let date: String
    /// 服务端生成时间（ISO8601）。
    public let generatedAt: String
    /// 今日最值得关注的 10 件事。
    public let top: [Event]
    /// 分类板块。
    public let sections: [Section]

    public init(date: String, generatedAt: String, top: [Event], sections: [Section]) {
        self.date = date
        self.generatedAt = generatedAt
        self.top = top
        self.sections = sections
    }
}
