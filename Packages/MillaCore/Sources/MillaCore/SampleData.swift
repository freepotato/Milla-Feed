import Foundation

/// 算法演示与测试用的内存样例数据。
///
/// 刻意制造两种典型场景：
/// - `TechPulse`：高质量 + 高产（8 条），用于验证 dailyLimit 与防霸屏；
/// - `SlowWeek`：全部是昨天的旧文，用于验证“当日无内容时回退最新”的兜底逻辑。
public enum SampleData {

    public static func make(
        now: Date = Date()
    ) -> (sources: [FeedSource], items: [FeedItem]) {
        let tech = FeedSource(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            title: "TechPulse",
            url: URL(string: "https://example.com/tech.xml")!,
            dailyLimit: 5,
            sampleSize: 3,
            qualityScore: 0.9
        )
        let world = FeedSource(
            id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
            title: "WorldWire",
            url: URL(string: "https://example.com/world.xml")!,
            dailyLimit: 4,
            sampleSize: 3,
            qualityScore: 0.6
        )
        let design = FeedSource(
            id: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
            title: "DesignDaily",
            url: URL(string: "https://example.com/design.xml")!,
            dailyLimit: 4,
            sampleSize: 2,
            qualityScore: 0.8
        )
        let slow = FeedSource(
            id: UUID(uuidString: "44444444-4444-4444-4444-444444444444")!,
            title: "SlowWeek",
            url: URL(string: "https://example.com/slow.xml")!,
            dailyLimit: 3,
            sampleSize: 2,
            qualityScore: 0.5
        )

        let sources = [tech, world, design, slow]

        func item(
            _ source: FeedSource,
            guid: String,
            title: String,
            hoursAgo: Double?,
            summary: String = "摘要内容，用于信息流卡片展示。"
        ) -> FeedItem {
            FeedItem(
                id: StableIdentifier.make([source.id.uuidString, guid]),
                sourceID: source.id,
                title: title,
                link: URL(string: "https://example.com/\(guid)"),
                summary: summary,
                contentHTML: "<p>\(summary)</p>",
                imageURL: URL(string: "https://example.com/\(guid).jpg"),
                author: "Author",
                publishedAt: hoursAgo.map { now.addingTimeInterval(-$0 * 3_600) }
            )
        }

        let items: [FeedItem] = [
            // TechPulse：高产源，8 条，最新 0.2h 前
            item(tech, guid: "t1", title: "TechPulse #1 刚刚发布", hoursAgo: 0.2),
            item(tech, guid: "t2", title: "TechPulse #2", hoursAgo: 0.8),
            item(tech, guid: "t3", title: "TechPulse #3", hoursAgo: 1.5),
            item(tech, guid: "t4", title: "TechPulse #4", hoursAgo: 2.5),
            item(tech, guid: "t5", title: "TechPulse #5（应被 dailyLimit 截掉）", hoursAgo: 3.5),
            item(tech, guid: "t6", title: "TechPulse #6（应被 dailyLimit 截掉）", hoursAgo: 4.5),
            item(tech, guid: "t7", title: "TechPulse #7（应被 dailyLimit 截掉）", hoursAgo: 5.5),
            item(tech, guid: "t8", title: "TechPulse #8（应被 dailyLimit 截掉）", hoursAgo: 6.5),

            // WorldWire：质量中等、很新
            item(world, guid: "w1", title: "WorldWire 突发一条", hoursAgo: 0.5),
            item(world, guid: "w2", title: "WorldWire 早间简报", hoursAgo: 3.0),
            item(world, guid: "w3", title: "WorldWire 昨日深度（非当日）", hoursAgo: 26),

            // DesignDaily：高质量、更新较久
            item(design, guid: "d1", title: "DesignDaily 封面设计趋势", hoursAgo: 1.0),
            item(design, guid: "d2", title: "DesignDaily 字体排印笔记", hoursAgo: 4.0),
            item(design, guid: "d3", title: "DesignDaily 旧文（非当日）", hoursAgo: 30),

            // SlowWeek：当日无更新，全部是旧文 -> 触发回退
            item(slow, guid: "s1", title: "SlowWeek 周报（昨天）", hoursAgo: 24),
            item(slow, guid: "s2", title: "SlowWeek 上周精选", hoursAgo: 72)
        ]

        return (sources, items)
    }
}
