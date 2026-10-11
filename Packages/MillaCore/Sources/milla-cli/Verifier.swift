//
//  Verifier.swift —— 不依赖 XCTest 的算法自检。
//  在任意平台执行 `swift run milla-cli verify` 即可验证解析与排序逻辑。
//

import Foundation
import MillaCore

enum Verifier {

    static func run() -> Int32 {
        var failures = 0

        func check(_ condition: Bool, _ message: String) {
            if condition {
                print("  ✓ \(message)")
            } else {
                failures += 1
                print("  ✗ \(message)")
            }
        }

        let now = ISO8601DateFormatter().date(from: "2026-10-11T12:00:00Z")!
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!

        // MARK: 1. 新鲜度半衰期
        do {
            let half = FeedRankingService.recencyScore(
                publishedAt: now.addingTimeInterval(-24 * 3600), now: now, halfLifeHours: 24
            )
            check(abs(half - 0.5) < 1e-4, "recencyScore 在一个半衰期处 ≈ 0.5（实际 \(half)）")
            let fresh = FeedRankingService.recencyScore(publishedAt: now, now: now)
            check(abs(fresh - 1.0) < 1e-4, "recencyScore 对刚发布内容 = 1.0")
        }

        // MARK: 2. dailyLimit + sampleSize
        do {
            let source = FeedSource(
                id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
                title: "Tech", url: URL(string: "https://x.com/t.xml")!,
                dailyLimit: 5, sampleSize: 3, qualityScore: 0.9
            )
            let items = (1...8).map { index -> FeedItem in
                FeedItem(
                    id: StableIdentifier.make(["t", "\(index)"]),
                    sourceID: source.id,
                    title: "t\(index)",
                    link: nil, summary: "", contentHTML: "", imageURL: nil, author: nil,
                    publishedAt: now.addingTimeInterval(-Double(index) * 3600)
                )
            }
            let outcome = FeedRankingService.rank(
                sources: [source], items: items, now: now, calendar: calendar
            )
            check(outcome.ranked.count == 3, "dailyLimit=5 截断后 sampleSize=3 生效（输出 \(outcome.ranked.count) 条）")
        }

        // MARK: 3. 交替显示
        do {
            let a = FeedSource(
                id: UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!,
                title: "A", url: URL(string: "https://x.com/a.xml")!,
                dailyLimit: 10, sampleSize: 5, qualityScore: 0.95
            )
            let b = FeedSource(
                id: UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")!,
                title: "B", url: URL(string: "https://x.com/b.xml")!,
                dailyLimit: 10, sampleSize: 5, qualityScore: 0.5
            )
            let items =
                (1...5).map { FeedItem(
                    id: StableIdentifier.make(["a", "\($0)"]), sourceID: a.id, title: "a\($0)",
                    link: nil, summary: "", contentHTML: "", imageURL: nil, author: nil,
                    publishedAt: now.addingTimeInterval(-Double($0) * 3600)
                ) } +
                (1...5).map { FeedItem(
                    id: StableIdentifier.make(["b", "\($0)"]), sourceID: b.id, title: "b\($0)",
                    link: nil, summary: "", contentHTML: "", imageURL: nil, author: nil,
                    publishedAt: now.addingTimeInterval(-Double($0) * 3600)
                ) }
            let outcome = FeedRankingService.rank(
                sources: [a, b], items: items, now: now, calendar: calendar
            )
            var adjacentSame = false
            for i in 1..<outcome.ranked.count {
                if outcome.ranked[i].sourceID == outcome.ranked[i - 1].sourceID {
                    adjacentSame = true
                }
            }
            check(!adjacentSame, "贪心交替合并：没有相邻同源源条目")
            check(outcome.ranked.first?.sourceID == a.id, "高质量源 A 排第一")
        }

        // MARK: 4. 去重池
        do {
            let source = FeedSource(
                id: UUID(uuidString: "cccccccc-cccc-cccc-cccc-cccccccccccc")!,
                title: "C", url: URL(string: "https://x.com/c.xml")!
            )
            let i1 = FeedItem(
                id: "shown-id", sourceID: source.id, title: "i1",
                link: nil, summary: "", contentHTML: "", imageURL: nil, author: nil,
                publishedAt: now.addingTimeInterval(-3600)
            )
            let i2 = FeedItem(
                id: "fresh-id", sourceID: source.id, title: "i2",
                link: nil, summary: "", contentHTML: "", imageURL: nil, author: nil,
                publishedAt: now.addingTimeInterval(-7200)
            )
            let outcome = FeedRankingService.rank(
                sources: [source], items: [i1, i2],
                shownIdentifiers: ["shown-id"], now: now, calendar: calendar
            )
            check(outcome.ranked.map(\.id) == ["fresh-id"], "去重池条目被排除")
            check(outcome.excludedAsShown == ["shown-id"], "被排除 ID 正确回填")
        }

        // MARK: 5. 权重归一化
        do {
            let config = RankingConfiguration(qualityWeight: 3, recencyWeight: 1)
            check(
                abs(config.normalizedWeights.quality - 0.75) < 1e-6
                && abs(config.normalizedWeights.recency - 0.25) < 1e-6,
                "权重自动归一化为 0.75 / 0.25"
            )
        }

        // MARK: 6. 确定性
        do {
            let sample = SampleData.make(now: now)
            let r1 = FeedRankingService.rank(
                sources: sample.sources, items: sample.items, now: now, calendar: calendar
            )
            let r2 = FeedRankingService.rank(
                sources: sample.sources, items: sample.items, now: now, calendar: calendar
            )
            check(r1.ranked.map(\.id) == r2.ranked.map(\.id), "默认确定性抽样可重复")
        }

        // MARK: 7. 端到端计数
        do {
            let sample = SampleData.make(now: now)
            let outcome = FeedRankingService.rank(
                sources: sample.sources, items: sample.items, now: now, calendar: calendar
            )
            let counts = Dictionary(grouping: outcome.ranked, by: \.sourceID).mapValues(\.count)
            let expected: [Int?] = [
                counts[sample.sources[0].id],
                counts[sample.sources[1].id],
                counts[sample.sources[2].id],
                counts[sample.sources[3].id]
            ]
            check(expected == [3, 2, 2, 2],
                  "端到端各源条数 = [3,2,2,2]（实际 \(expected.map { String(describing: $0) }.joined(separator: ","))）")
            check(outcome.ranked.count == 9, "端到端总条数 = 9")
        }

        // MARK: 8. RSS 解析
        do {
            let source = FeedSource(
                id: UUID(uuidString: "dddddddd-dddd-dddd-dddd-dddddddddddd")!,
                title: "Parser", url: URL(string: "https://x.com/p.xml")!
            )
            let xml = """
            <rss version="2.0" xmlns:media="http://search.yahoo.com/mrss/"
                 xmlns:dc="http://purl.org/dc/elements/1.1/"
                 xmlns:content="http://purl.org/rss/1.0/modules/content/"><channel>
              <title>Parser Feed</title>
              <item>
                <title>Hello &amp; Bye</title>
                <link>https://x.com/1</link>
                <guid>g1</guid>
                <pubDate>Sun, 11 Oct 2026 09:30:00 GMT</pubDate>
                <dc:creator>Jane</dc:creator>
                <media:content url="https://x.com/c.jpg" type="image/jpeg"/>
                <description><![CDATA[<p>Short text.</p>]]></description>
              </item>
            </channel></rss>
            """
            let parsed = try SwiftFeedParser().parse(data: Data(xml.utf8), source: source)
            let item = parsed.items.first
            check(item?.title == "Hello & Bye", "RSS：实体解码")
            check(item?.author == "Jane", "RSS：dc:creator 作者")
            check(item?.imageURL?.absoluteString == "https://x.com/c.jpg", "RSS：media:content 封面")
            check(item?.summary == "Short text.", "RSS：CDATA 摘要去标签")
            check(item?.id == StableIdentifier.make([source.id.uuidString, "g1"]), "RSS：稳定 ID")
        } catch {
            check(false, "RSS 解析失败: \(error)")
        }

        // MARK: 9. Atom 解析
        do {
            let source = FeedSource(
                id: UUID(uuidString: "eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee")!,
                title: "Atom", url: URL(string: "https://x.com/a.xml")!
            )
            let xml = """
            <feed xmlns="http://www.w3.org/2005/Atom"><title>Atom Feed</title>
            <entry>
              <title>Atom One</title>
              <id>tag:x,2026:1</id>
              <link rel="alternate" href="https://x.com/a1"/>
              <link rel="edit" href="https://x.com/e1"/>
              <published>2026-10-11T08:00:00Z</published>
              <author><name>John</name></author>
              <content type="html">&lt;img src="https://x.com/a.png"/&gt;&lt;p&gt;Body&lt;/p&gt;</content>
            </entry></feed>
            """
            let parsed = try SwiftFeedParser().parse(data: Data(xml.utf8), source: source)
            let item = parsed.items.first
            check(parsed.title == "Atom Feed", "Atom：feed 标题")
            check(item?.link?.absoluteString == "https://x.com/a1", "Atom：优先 rel=alternate 链接")
            check(item?.author == "John", "Atom：作者")
            check(item?.imageURL?.absoluteString == "https://x.com/a.png", "Atom：正文内封面图")
        } catch {
            check(false, "Atom 解析失败: \(error)")
        }

        print("")
        if failures == 0 {
            print("✅ 全部自检通过")
            return 0
        } else {
            print("❌ \(failures) 项自检失败")
            return 1
        }
    }
}
