import XCTest
@testable import MillaCore

final class RemoShuangRankedTests: XCTestCase {

    /// /api/ranked 真实字段的子集：接口顺序与热度顺序故意不一致，
    /// 用来证明 App 严格保持接口顺序、不再二次排序。
    private let rankedJSON = """
    {
      "success": true,
      "data": {
        "page": 1,
        "totalPages": 10,
        "items": [
          {
            "position": 1, "id": "r1", "title": "头条一号",
            "url": "https://example.com/1", "sourceName": "东方财富",
            "sourceCategory": "财经", "heatValue": 78030590,
            "heatLabel": "7803.1 万热度",
            "sources": [{"key": "eastmoney", "name": "东方财富"},
                        {"key": "cls", "name": "财联社"}]
          },
          {
            "position": 2, "id": "r2", "title": "头条二号",
            "url": "https://example.com/2", "sourceName": "中国新闻网",
            "sourceCategory": "新闻", "heatValue": 34110000,
            "heatLabel": "3411.0 万热度",
            "sources": [{"key": "chinanews", "name": "中国新闻网"}]
          },
          {
            "position": 3, "id": "r3", "title": "科技三条",
            "url": "https://example.com/3", "sourceName": "IT之家",
            "sourceCategory": "科技", "heatValue": 900000000,
            "heatLabel": "9.0 亿热度",
            "sources": [{"key": "ithome", "name": "IT之家"}]
          }
        ]
      }
    }
    """

    private let trendsJSON = """
    {
      "success": true,
      "available": true,
      "rising": [
        {
          "eventId": "ev_1", "title": "宇树科技发布上市后首份财报",
          "url": "https://m.163.com/a", "category": "新闻",
          "heat": 53640048, "velocity": 89.193, "sourceVelocity": 0.5,
          "trendScore": 12, "sourceCount": 2, "newSources": 1,
          "trendState": "rising",
          "firstSeenAt": "2026-10-28T11:27:53.000Z"
        }
      ]
    }
    """

    private func decodedPage() throws -> RemoShuangRanked.Page {
        try RemoShuangRanked.decodePage(from: Data(rankedJSON.utf8))
    }

    func testDecodePage() throws {
        let page = try decodedPage()
        XCTAssertEqual(page.page, 1)
        XCTAssertEqual(page.totalPages, 10)
        XCTAssertEqual(page.items.count, 3)
        XCTAssertEqual(page.items[0].id, "r1")
        XCTAssertEqual(page.items[0].sourceCount, 2)
        XCTAssertEqual(page.items[2].heatLabel, "9.0 亿热度")
    }

    /// 综合榜必须按 position 原样输出，不能按 heatValue 重排。
    func testCombinedKeepsAPISequence() throws {
        let entries = RemoShuangRanked.entries(from: try decodedPage().items, category: nil)
        XCTAssertEqual(entries.map(\.title), ["头条一号", "头条二号", "科技三条"])
        XCTAssertEqual(entries[0].sourceName, "东方财富")
        XCTAssertEqual(entries[0].sourceCount, 2)
        XCTAssertEqual(entries[0].link?.absoluteString, "https://example.com/1")
    }

    /// 接口的 id 是榜单快照标识（如 "r1"），会跨条目重复；
    /// Entry.id 必须唯一，否则列表会吞掉部分行。
    func testEntryIDsStayUniqueWhenAPIRepeatsIDs() {
        let items = [
            RemoShuangRanked.Item(
                position: 1, id: "r1", title: "甲", url: "https://example.com/1",
                sourceName: "来源", sourceCategory: "科技", heatValue: 1,
                heatLabel: "1 万热度", sources: []
            ),
            RemoShuangRanked.Item(
                position: 2, id: "r1", title: "乙", url: "https://example.com/2",
                sourceName: "来源", sourceCategory: "财经", heatValue: 2,
                heatLabel: "2 万热度", sources: []
            ),
        ]
        let entries = RemoShuangRanked.entries(from: items, category: nil)
        XCTAssertEqual(entries.map(\.title), ["甲", "乙"])
        XCTAssertEqual(Set(entries.map(\.id)).count, 2)
    }

    /// 分类页保留原顺序（position 3 的科技条目单独成页）。
    func testCategoryFilterKeepsSequence() throws {
        let items = try decodedPage().items
        XCTAssertEqual(
            RemoShuangRanked.entries(from: items, category: "科技").map(\.title),
            ["科技三条"]
        )
        XCTAssertEqual(
            RemoShuangRanked.entries(from: items, category: "新闻").map(\.title),
            ["头条二号"]
        )
    }

    func testCategoryLabelsFollowSiteOrder() throws {
        let items = try decodedPage().items
        // 站点顺序里"科技"在"财经"之前；接口出现的分类全部保留
        XCTAssertEqual(RemoShuangRanked.categoryLabels(for: items), ["科技", "财经", "新闻"])
    }

    func testDecodeRising() throws {
        let rising = try RemoShuangRanked.decodeTrends(from: Data(trendsJSON.utf8))
        XCTAssertEqual(rising.count, 1)
        XCTAssertEqual(rising[0].title, "宇树科技发布上市后首份财报")
        XCTAssertEqual(rising[0].risePercent, 8919)
        XCTAssertEqual(rising[0].sourceCount, 2)
        XCTAssertEqual(rising[0].newSources, 1)
        XCTAssertNotNil(rising[0].firstSeenDate)
        XCTAssertEqual(rising[0].link?.host, "m.163.com")
    }

    func testEntryCodableRoundTrip() throws {
        let entries = RemoShuangRanked.entries(from: try decodedPage().items, category: nil)
        let data = try JSONEncoder().encode(entries)
        let again = try JSONDecoder().decode([RemoShuangRanked.Entry].self, from: data)
        XCTAssertEqual(again, entries)
    }
}
