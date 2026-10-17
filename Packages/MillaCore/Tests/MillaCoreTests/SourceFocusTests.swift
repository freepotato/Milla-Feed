import XCTest
@testable import MillaCore

final class SourceFocusTests: XCTestCase {

    private let now = ISO8601DateFormatter().date(from: "2026-10-17T12:00:00Z")!
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private func source(focus: SourceFocus, quality: Double = 0.8) -> FeedSource {
        FeedSource(
            id: UUID(),
            title: focus.rawValue,
            url: URL(string: "https://example.com/\(focus.rawValue).xml")!,
            qualityScore: quality,
            focus: focus
        )
    }

    private func item(source: FeedSource, guid: String, hoursAgo: Double) -> FeedItem {
        FeedItem(
            id: StableIdentifier.make([source.id.uuidString, guid]),
            sourceID: source.id,
            title: guid,
            link: nil,
            summary: "",
            contentHTML: "",
            imageURL: nil,
            author: nil,
            publishedAt: now.addingTimeInterval(-hoursAgo * 3_600)
        )
    }

    // MARK: 有效权重

    func testEffectiveWeightsShiftByFocus() {
        let global = (quality: 0.6, recency: 0.4)

        let balanced = FeedRankingService.effectiveWeights(global: global, focus: .balanced)
        XCTAssertEqual(balanced.quality, 0.6, accuracy: 1e-6)
        XCTAssertEqual(balanced.recency, 0.4, accuracy: 1e-6)

        let timely = FeedRankingService.effectiveWeights(global: global, focus: .timeliness)
        XCTAssertGreaterThan(timely.recency, timely.quality)

        let deep = FeedRankingService.effectiveWeights(global: global, focus: .depth)
        XCTAssertGreaterThan(deep.quality, deep.recency)
        XCTAssertGreaterThan(deep.quality, balanced.quality)
    }

    // MARK: 有效半衰期

    func testEffectiveHalfLifeByFocus() {
        XCTAssertEqual(FeedRankingService.effectiveHalfLife(global: 24, focus: .balanced), 24, accuracy: 1e-6)
        // 时效源半衰期不变（缩短会反向压低新文章 recency，见实现注释）
        XCTAssertEqual(FeedRankingService.effectiveHalfLife(global: 24, focus: .timeliness), 24, accuracy: 1e-6)
        XCTAssertEqual(FeedRankingService.effectiveHalfLife(global: 24, focus: .depth), 96, accuracy: 1e-6)
        // 下限保护
        XCTAssertEqual(FeedRankingService.effectiveHalfLife(global: 0.5, focus: .timeliness), 1, accuracy: 1e-6)
    }

    // MARK: 深度源旧文章不衰减

    func testDepthFocusKeepsOldArticleCompetitive() {
        // 同样 3 天前、同质量分：深度源文章得分应显著高于均衡源文章
        let deepSource = source(focus: .depth)
        let balancedSource = source(focus: .balanced)
        let deepItem = item(source: deepSource, guid: "deep", hoursAgo: 72)
        let balancedItem = item(source: balancedSource, guid: "bal", hoursAgo: 72)

        let outcome = FeedRankingService.rank(
            sources: [deepSource, balancedSource],
            items: [deepItem, balancedItem],
            now: now,
            calendar: calendar
        )

        let deepScore = outcome.ranked.first { $0.item.id == deepItem.id }?.score ?? 0
        let balScore = outcome.ranked.first { $0.item.id == balancedItem.id }?.score ?? 0
        XCTAssertGreaterThan(deepScore, balScore)
        XCTAssertEqual(outcome.ranked.first?.item.id, deepItem.id)
    }

    // MARK: 时效源新鲜文章优先

    func testTimelinessFocusFavorsFreshArticle() {
        // 两源同质量：时效源 2 小时前的文章 vs 均衡源 2 小时前的文章，
        // 时效源得分更高（新鲜度权重更大）
        let timelySource = source(focus: .timeliness)
        let balancedSource = source(focus: .balanced)
        let timelyItem = item(source: timelySource, guid: "fresh", hoursAgo: 2)
        let balancedItem = item(source: balancedSource, guid: "same-age", hoursAgo: 2)

        let outcome = FeedRankingService.rank(
            sources: [timelySource, balancedSource],
            items: [timelyItem, balancedItem],
            now: now,
            calendar: calendar
        )

        let timelyScore = outcome.ranked.first { $0.item.id == timelyItem.id }?.score ?? 0
        let balScore = outcome.ranked.first { $0.item.id == balancedItem.id }?.score ?? 0
        XCTAssertGreaterThan(timelyScore, balScore)
    }

    // MARK: 时效源过气快讯让位

    func testTimelinessFocusDemotesStaleArticle() {
        // 两源同质量：同样 48 小时前，时效源文章得分低于均衡源——
        // 质量贡献占比下降，过气快讯迅速让位
        let timelySource = source(focus: .timeliness)
        let balancedSource = source(focus: .balanced)
        let timelyItem = item(source: timelySource, guid: "stale-news", hoursAgo: 48)
        let balancedItem = item(source: balancedSource, guid: "same-age", hoursAgo: 48)

        let outcome = FeedRankingService.rank(
            sources: [timelySource, balancedSource],
            items: [timelyItem, balancedItem],
            now: now,
            calendar: calendar
        )

        let timelyScore = outcome.ranked.first { $0.item.id == timelyItem.id }?.score ?? 0
        let balScore = outcome.ranked.first { $0.item.id == balancedItem.id }?.score ?? 0
        XCTAssertLessThan(timelyScore, balScore)
    }

    // MARK: Codable 向后兼容

    func testFeedSourceDecodesWithoutFocusField() throws {
        let json = """
        {
          "id": "11111111-1111-1111-1111-111111111111",
          "title": "Legacy",
          "url": "https://example.com/feed",
          "isEnabled": true,
          "dailyLimit": 10,
          "sampleSize": 5,
          "qualityScore": 0.8,
          "addedAt": 0
        }
        """.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let source = try decoder.decode(FeedSource.self, from: json)
        XCTAssertEqual(source.focus, .balanced)
    }
}
