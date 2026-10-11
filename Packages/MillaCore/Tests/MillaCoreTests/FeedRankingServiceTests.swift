import XCTest
@testable import MillaCore

final class FeedRankingServiceTests: XCTestCase {

    /// 固定时钟：2026-10-11 12:00:00 UTC
    private let now = ISO8601DateFormatter().date(from: "2026-10-11T12:00:00Z")!
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private func source(
        _ uuid: String,
        title: String,
        dailyLimit: Int = 10,
        sampleSize: Int = 5,
        quality: Double = 0.8
    ) -> FeedSource {
        FeedSource(
            id: UUID(uuidString: uuid)!,
            title: title,
            url: URL(string: "https://example.com/\(title).xml")!,
            dailyLimit: dailyLimit,
            sampleSize: sampleSize,
            qualityScore: quality
        )
    }

    private func item(
        source: FeedSource,
        guid: String,
        title: String? = nil,
        hoursAgo: Double?
    ) -> FeedItem {
        FeedItem(
            id: StableIdentifier.make([source.id.uuidString, guid]),
            sourceID: source.id,
            title: title ?? "\(guid)-title",
            link: URL(string: "https://example.com/\(guid)"),
            summary: "summary",
            contentHTML: "",
            imageURL: nil,
            author: nil,
            publishedAt: hoursAgo.map { now.addingTimeInterval(-$0 * 3_600) }
        )
    }

    // MARK: 新鲜度

    func testRecencyScoreHalfLifeDecay() {
        let score = FeedRankingService.recencyScore(
            publishedAt: now.addingTimeInterval(-24 * 3_600),
            now: now,
            halfLifeHours: 24
        )
        XCTAssertEqual(score, 0.5, accuracy: 0.0001)

        let fresh = FeedRankingService.recencyScore(publishedAt: now, now: now)
        XCTAssertEqual(fresh, 1.0, accuracy: 0.0001)

        let missing = FeedRankingService.recencyScore(publishedAt: nil, now: now, missingFallback: 0.2)
        XCTAssertEqual(missing, 0.2, accuracy: 0.0001)
    }

    // MARK: dailyLimit / sampleSize

    func testDailyLimitAndSampleSizeCapPerSource() {
        let tech = source("11111111-1111-1111-1111-111111111111",
                          title: "Tech", dailyLimit: 5, sampleSize: 3, quality: 0.9)
        let items = (1...8).map { item(source: tech, guid: "t\($0)", hoursAgo: Double($0)) }

        let outcome = FeedRankingService.rank(
            sources: [tech], items: items, now: now, calendar: calendar
        )
        XCTAssertEqual(outcome.ranked.count, 3)
        // 抽样应保留最新/最强的三条（t1 t2 t3）
        XCTAssertEqual(Set(outcome.ranked.map(\.item.id)),
                       Set(items.prefix(3).map(\.id)))
    }

    // MARK: 交替显示

    func testInterleavingPreventsSourceMonopoly() {
        let a = source("11111111-1111-1111-1111-111111111111", title: "A",
                       dailyLimit: 10, sampleSize: 5, quality: 0.95)
        let b = source("22222222-2222-2222-2222-222222222222", title: "B",
                       dailyLimit: 10, sampleSize: 5, quality: 0.5)
        let items =
            (1...5).map { item(source: a, guid: "a\($0)", hoursAgo: Double($0)) } +
            (1...5).map { item(source: b, guid: "b\($0)", hoursAgo: Double($0)) }

        let outcome = FeedRankingService.rank(
            sources: [a, b], items: items, now: now, calendar: calendar
        )
        XCTAssertEqual(outcome.ranked.count, 10)

        // 关键不变量：只要两个源都还有剩余，相邻两条不能来自同一源
        for index in 1..<outcome.ranked.count {
            let remainingAfterPrev = Set(outcome.ranked[index...].map(\.sourceID))
            if remainingAfterPrev.count > 1 {
                XCTAssertNotEqual(
                    outcome.ranked[index].sourceID,
                    outcome.ranked[index - 1].sourceID,
                    "位置 \(index) 出现连续同源源霸屏"
                )
            }
        }
        // A 源质量高，第一条应来自 A
        XCTAssertEqual(outcome.ranked.first?.sourceID, a.id)
    }

    // MARK: 去重池

    func testShownIdentifiersAreExcluded() {
        let a = source("11111111-1111-1111-1111-111111111111", title: "A")
        let i1 = item(source: a, guid: "i1", hoursAgo: 1)
        let i2 = item(source: a, guid: "i2", hoursAgo: 2)

        let outcome = FeedRankingService.rank(
            sources: [a],
            items: [i1, i2],
            shownIdentifiers: [i1.id],
            now: now,
            calendar: calendar
        )
        XCTAssertEqual(outcome.ranked.map(\.item.id), [i2.id])
        XCTAssertEqual(outcome.excludedAsShown, [i1.id])
    }

    // MARK: 停用源

    func testDisabledSourceExcluded() {
        var a = source("11111111-1111-1111-1111-111111111111", title: "A")
        a.isEnabled = false
        let items = [item(source: a, guid: "i1", hoursAgo: 1)]

        let outcome = FeedRankingService.rank(
            sources: [a], items: items, now: now, calendar: calendar
        )
        XCTAssertTrue(outcome.ranked.isEmpty)
    }

    // MARK: 权重

    func testQualityOnlyWeightPicksHighQualityFirst() {
        let high = source("11111111-1111-1111-1111-111111111111", title: "High", quality: 1.0)
        let low = source("22222222-2222-2222-2222-222222222222", title: "Low", quality: 0.1)
        let items = [
            item(source: high, guid: "h", hoursAgo: 8),
            item(source: low, guid: "l", hoursAgo: 0)
        ]

        let outcome = FeedRankingService.rank(
            sources: [high, low],
            items: items,
            config: RankingConfiguration(qualityWeight: 1, recencyWeight: 0),
            now: now,
            calendar: calendar
        )
        XCTAssertEqual(outcome.ranked.first?.sourceID, high.id)
        XCTAssertEqual(outcome.ranked.first?.score, 1.0, accuracy: 0.0001)
    }

    func testWeightsAreNormalized() {
        let config = RankingConfiguration(qualityWeight: 3, recencyWeight: 1)
        XCTAssertEqual(config.normalizedWeights.quality, 0.75, accuracy: 0.0001)
        XCTAssertEqual(config.normalizedWeights.recency, 0.25, accuracy: 0.0001)
    }

    // MARK: 确定性

    func testDeterministicTopKIsRepeatable() {
        let sample = SampleData.make(now: now)
        let first = FeedRankingService.rank(
            sources: sample.sources, items: sample.items, now: now, calendar: calendar
        )
        let second = FeedRankingService.rank(
            sources: sample.sources, items: sample.items, now: now, calendar: calendar
        )
        XCTAssertEqual(first.ranked.map(\.id), second.ranked.map(\.id))
    }

    func testStochasticSamplingWithFixedSeedIsRepeatable() {
        let sample = SampleData.make(now: now)
        let config = RankingConfiguration(
            stochasticSampling: true,
            randomSeed: 20260611
        )
        let first = FeedRankingService.rank(
            sources: sample.sources, items: sample.items,
            config: config, now: now, calendar: calendar
        )
        let second = FeedRankingService.rank(
            sources: sample.sources, items: sample.items,
            config: config, now: now, calendar: calendar
        )
        XCTAssertEqual(first.ranked.map(\.id), second.ranked.map(\.id))
        XCTAssertEqual(first.ranked.count, second.ranked.count)
    }

    // MARK: 旧内容回退

    func testFallbackToNewestWhenNoTodayContent() {
        let slow = source("44444444-4444-4444-4444-444444444444",
                          title: "Slow", dailyLimit: 3, sampleSize: 2, quality: 0.5)
        let items = [
            item(source: slow, guid: "s1", hoursAgo: 24),
            item(source: slow, guid: "s2", hoursAgo: 72)
        ]

        let outcome = FeedRankingService.rank(
            sources: [slow], items: items, now: now, calendar: calendar
        )
        // 回退取最新两条
        XCTAssertEqual(outcome.ranked.map(\.item.id), items.map(\.id))
    }

    // MARK: 端到端样例

    func testSampleDataEndToEndCounts() {
        let sample = SampleData.make(now: now)
        let outcome = FeedRankingService.rank(
            sources: sample.sources, items: sample.items, now: now, calendar: calendar
        )

        let counts = Dictionary(grouping: outcome.ranked, by: \.sourceID).mapValues(\.count)
        XCTAssertEqual(counts[sample.sources[0].id], 3, "TechPulse: dailyLimit 5 -> sampleSize 3")
        XCTAssertEqual(counts[sample.sources[1].id], 2, "WorldWire: 当日 2 条")
        XCTAssertEqual(counts[sample.sources[2].id], 2, "DesignDaily: 当日 2 条")
        XCTAssertEqual(counts[sample.sources[3].id], 2, "SlowWeek: 回退最新 2 条")
        XCTAssertEqual(outcome.ranked.count, 9)
        XCTAssertTrue(outcome.excludedAsShown.isEmpty)
    }
}
