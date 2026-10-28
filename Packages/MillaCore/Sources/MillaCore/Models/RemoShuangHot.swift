import Foundation

/// 热摸爽主页榜单（https://remoshuang.com/api/hot）的响应模型与展示组装。
///
/// 接口按来源分组（知乎/微博/IT之家…共数百个，各有大类 category 与 rank 榜单），
/// 一次抓取即拿到全部大类；App 层按小时缓存整份组装结果。
public enum RemoShuangHot {

    public struct Item: Codable, Sendable {
        public let rank: Int
        public let title: String
        public let url: String
        /// 热度原文（如 "17201 万热度"、"241回复"，可能为空）。
        public let heat: String

        public init(rank: Int, title: String, url: String, heat: String) {
            self.rank = rank
            self.title = title
            self.url = url
            self.heat = heat
        }
    }

    public struct Source: Codable, Sendable, Identifiable {
        public let key: String
        public let name: String
        /// 大类（如 社区/科技/新闻），用于新闻页分类切换。
        public let category: String
        public let items: [Item]

        public var id: String { key }

        public init(key: String, name: String, category: String, items: [Item]) {
            self.key = key
            self.name = name
            self.category = category
            self.items = items
        }
    }

    /// 扁平化后的列表条目（UI 直接展示）。
    public struct Entry: Codable, Sendable, Identifiable {
        public let id: String
        public let title: String
        public let link: URL?
        public let heat: String
        public let sourceName: String

        public init(id: String, title: String, link: URL?, heat: String, sourceName: String) {
            self.id = id
            self.title = title
            self.link = link
            self.heat = heat
            self.sourceName = sourceName
        }
    }

    /// 从接口 envelope 解码来源列表：{"success":true,"data":[...]}。
    public static func decodeSources(from data: Data) throws -> [Source] {
        struct Envelope: Decodable { let data: [Source] }
        return try JSONDecoder().decode(Envelope.self, from: data).data
    }

    /// 站点（remoshuang.com 首页 / 分类页）的分类顺序。
    /// "其他" 是接口里的兜底分组，站点没有对应标签页，不进入分类导航。
    public static let siteCategoryOrder = [
        "科技", "AI", "财经", "新闻", "游戏", "娱乐", "社区", "发现机会",
        "阅读", "知识", "生活", "编程", "体育", "外国媒体", "健康", "设计", "教育"
    ]

    /// 分类导航：按站点顺序排列，只保留接口实际出现的分类；
    /// 接口新增了站点尚未列出顺序的分类时追加在末尾（"其他" 除外）。
    public static func categoryLabels(of sources: [Source]) -> [String] {
        let present = Set(sources.map(\.category).filter { !$0.isEmpty })
        let ordered = siteCategoryOrder.filter { present.contains($0) }
        let extras = present
            .subtracting(siteCategoryOrder)
            .subtracting(["其他"])
            .sorted()
        return ordered + extras
    }

    /// 组装条目：
    /// - `categoryLabel == nil` → 综合榜，全部来源合并后按热度降序（与站点榜单一致）；
    /// - 指定分类 → 该分类下所有来源合并后按热度降序。
    /// 热度相同按名次靠前者优先，再按来源名稳定排序。
    public static func entries(
        from sources: [Source],
        categoryLabel: String?,
        limit: Int = 50
    ) -> [Entry] {
        let filtered = sources.filter { source in
            guard !source.items.isEmpty else { return false }
            return categoryLabel == nil || source.category == categoryLabel
        }

        var pool: [(entry: Entry, heat: Double, rank: Int)] = []
        for source in filtered {
            for item in source.items {
                pool.append((
                    Entry(
                        id: "\(source.key)-r\(item.rank)",
                        title: item.title,
                        link: URL(string: item.url),
                        heat: item.heat,
                        sourceName: source.name
                    ),
                    heatValue(item.heat),
                    item.rank
                ))
            }
        }
        pool.sort { lhs, rhs in
            if lhs.heat != rhs.heat { return lhs.heat > rhs.heat }
            if lhs.rank != rhs.rank { return lhs.rank < rhs.rank }
            return lhs.entry.id < rhs.entry.id
        }
        return Array(pool.prefix(limit).map(\.entry))
    }

    /// "17201 万热度" → 172_010_000；"241回复" → 241；空串/无数字 → 0。
    static func heatValue(_ heat: String) -> Double {
        guard let match = heat.range(of: "[0-9]+(?:\\.[0-9]+)?", options: .regularExpression) else {
            return 0
        }
        let number = Double(heat[match]) ?? 0
        return heat.contains("万") ? number * 10_000 : number
    }
}
