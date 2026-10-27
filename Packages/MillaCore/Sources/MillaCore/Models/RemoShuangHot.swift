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

    /// 大类展示顺序：按来源首次出现的顺序去重。
    public static func categoryLabels(of sources: [Source]) -> [String] {
        var seen = Set<String>()
        return sources.compactMap { source in
            guard !source.category.isEmpty, !seen.contains(source.category) else { return nil }
            seen.insert(source.category)
            return source.category
        }
    }

    /// 组装一个分类（nil = 综合）的条目：
    /// 按 rank 从 1 开始逐轮取各来源该名次的条目，同一轮内按热度降序。
    /// 名次优先保证各来源头部内容排在前面；热度只作同轮内的排序参考。
    public static func entries(
        from sources: [Source],
        categoryLabel: String?,
        limit: Int = 50
    ) -> [Entry] {
        let filtered = sources.filter {
            !$0.items.isEmpty && (categoryLabel == nil || $0.category == categoryLabel)
        }
        guard let maxCount = filtered.map({ $0.items.count }).max() else { return [] }
        var result: [Entry] = []
        for rankIndex in 0..<maxCount {
            var round: [(source: Source, item: Item)] = []
            for source in filtered where source.items.count > rankIndex {
                round.append((source, source.items[rankIndex]))
            }
            round.sort { heatValue($0.item.heat) > heatValue($1.item.heat) }
            for (source, item) in round {
                result.append(Entry(
                    id: "\(source.key)-r\(item.rank)",
                    title: item.title,
                    link: URL(string: item.url),
                    heat: item.heat,
                    sourceName: source.name
                ))
            }
            if result.count >= limit { break }
        }
        return Array(result.prefix(limit))
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
