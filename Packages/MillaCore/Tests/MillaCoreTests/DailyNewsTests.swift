import XCTest
@testable import MillaCore

final class DailyNewsTests: XCTestCase {

    /// 固定时钟：2026-10-17 08:00:00 UTC（东八区 16:00）
    private let now = ISO8601DateFormatter().date(from: "2026-10-17T08:00:00Z")!
    private var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private func source(
        _ uuid: String,
        focus: SourceFocus = .timeliness,
        quality: Double = 0.8,
        enabled: Bool = true
    ) -> FeedSource {
        FeedSource(
            id: UUID(uuidString: uuid)!,
            title: uuid.prefix(4).description,
            url: URL(string: "https://example.com/\(uuid).xml")!,
            isEnabled: enabled,
            qualityScore: quality,
            focus: focus
        )
    }

    private func item(
        source: FeedSource,
        guid: String,
        hoursAgo: Double?
    ) -> FeedItem {
        FeedItem(
            id: StableIdentifier.make([source.id.uuidString, guid]),
            sourceID: source.id,
            title: "\(guid)-title",
            link: nil,
            summary: "summary",
            contentHTML: "",
            imageURL: nil,
            author: nil,
            publishedAt: hoursAgo.map { now.addingTimeInterval(-$0 * 3_600) }
        )
    }

    // MARK: - 时段

    func testSlotBoundaries() throws {
        let formatter = ISO8601DateFormatter()

        // 6:59 → nil（凌晨无时段）
        let earlyMorning = formatter.date(from: "2026-10-17T06:59:00Z")!
        XCTAssertNil(DailyNews.currentSlot(now: earlyMorning, calendar: utcCalendar))

        // 7:00 → 上午版
        let seven = formatter.date(from: "2026-10-17T07:00:00Z")!
        let am = DailyNews.currentSlot(now: seven, calendar: utcCalendar)
        XCTAssertEqual(am?.key, "2026-10-17-am")
        XCTAssertEqual(am?.name, "上午版")

        // 11:59 仍是上午版
        let beforeNoon = formatter.date(from: "2026-10-17T11:59:00Z")!
        XCTAssertEqual(
            DailyNews.currentSlot(now: beforeNoon, calendar: utcCalendar)?.key,
            "2026-10-17-am"
        )

        // 12:00 → 午后版
        let noon = formatter.date(from: "2026-10-17T12:00:00Z")!
        XCTAssertEqual(
            DailyNews.currentSlot(now: noon, calendar: utcCalendar)?.key,
            "2026-10-17-pm"
        )

        // 23:59 仍是午后版
        let lateNight = formatter.date(from: "2026-10-17T23:59:00Z")!
        XCTAssertEqual(
            DailyNews.currentSlot(now: lateNight, calendar: utcCalendar)?.key,
            "2026-10-17-pm"
        )
    }

    // MARK: - 候选挑选

    func testDepthSourcesAreExcluded() {
        let news = source("11111111-1111-1111-1111-111111111111", focus: .timeliness)
        let longform = source("22222222-2222-2222-2222-222222222222", focus: .depth, quality: 1.0)
        let items = [
            item(source: news, guid: "n1", hoursAgo: 2),
            item(source: longform, guid: "d1", hoursAgo: 1) // 即使更新、质量更高也不入选
        ]

        let top = DailyNews.topItems(
            sources: [news, longform], items: items, now: now
        )
        XCTAssertEqual(top.map(\.item.id), [items[0].id])
    }

    func testWindowExcludesOldAndFutureArticles() {
        let news = source("11111111-1111-1111-1111-111111111111", focus: .timeliness)
        let fresh = item(source: news, guid: "fresh", hoursAgo: 23.5)
        let stale = item(source: news, guid: "stale", hoursAgo: 24.5)
        let future = item(source: news, guid: "future", hoursAgo: -1)

        let top = DailyNews.topItems(
            sources: [news],
            items: [fresh, stale, future],
            now: now
        )
        XCTAssertEqual(top.map(\.item.id), [fresh.id])
    }

    func testBalancedSourceIncludedButTimelinessWinsForFreshNews() {
        let timely = source("11111111-1111-1111-1111-111111111111",
                            focus: .timeliness, quality: 0.8)
        let balanced = source("22222222-2222-2222-2222-222222222222",
                              focus: .balanced, quality: 0.8)
        // 两源同质量、同发布时间：时效源有效新鲜度权重更高，应排前
        let a = item(source: timely, guid: "a", hoursAgo: 3)
        let b = item(source: balanced, guid: "b", hoursAgo: 3)

        let top = DailyNews.topItems(
            sources: [timely, balanced], items: [b, a], now: now
        )
        XCTAssertEqual(Set(top.map(\.item.id)), Set([a.id, b.id]))
        XCTAssertEqual(top.first?.item.id, a.id)
    }

    func testLimitAndTieBreakByNewest() {
        let news = source("11111111-1111-1111-1111-111111111111", focus: .timeliness)
        let items = (1...15).map { item(source: news, guid: "n\($0)", hoursAgo: Double($0)) }

        let top = DailyNews.topItems(
            sources: [news], items: items, now: now, limit: 10
        )
        XCTAssertEqual(top.count, 10)
        // 同源同质量：新者分数高，顺序应严格按发布时间倒序（n1 最新在前）
        XCTAssertEqual(top.map(\.item.id), items.prefix(10).map(\.id))
    }

    // MARK: - 一句话概括

    func testHeadlineTakesFirstSentence() {
        let headline = DailyNews.makeHeadline(
            title: "备用标题",
            summary: "苹果发布新款 iPhone，搭载 A19 芯片。发布会还介绍了新手表。"
        )
        XCTAssertEqual(headline, "苹果发布新款 iPhone，搭载 A19 芯片")
    }

    func testHeadlineAppendsSecondSentenceWhenFirstTooShort() {
        let headline = DailyNews.makeHeadline(
            title: "备用标题",
            summary: "快讯。苹果公司于今日凌晨正式发布了全新一代旗舰手机产品。"
        )
        XCTAssertEqual(headline, "快讯，苹果公司于今日凌晨正式发布了全新一代旗舰手机产品")
    }

    func testHeadlineTruncatesLongText() {
        let long = String(repeating: "很长的句子", count: 30)
        let headline = DailyNews.makeHeadline(title: "备用标题", summary: long)
        XCTAssertTrue(headline.hasSuffix("…"))
        XCTAssertEqual(headline.count, 57) // 56 + 省略号
    }

    func testHeadlineFallsBackToTitleWhenSummaryEmpty() {
        XCTAssertEqual(
            DailyNews.makeHeadline(title: "只有标题", summary: "  \n "),
            "只有标题"
        )
    }
}
