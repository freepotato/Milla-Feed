import XCTest
@testable import MillaCore

final class RemoShuangHotTests: XCTestCase {

    /// 接口真实字段的子集（多来源、两大类、不同热度形态）。
    private let sampleJSON = """
    {
      "success": true,
      "data": [
        {
          "name": "知乎", "icon": "zh", "color": "#0066ff", "category": "社区", "key": "zhihu",
          "items": [
            {"id": "r1", "rank": 1, "title": "知乎热一", "url": "https://www.zhihu.com/q/1",
             "heat": "8000 万热度", "image": "", "description": ""},
            {"id": "r2", "rank": 2, "title": "知乎热二", "url": "https://www.zhihu.com/q/2",
             "heat": "500 万热度", "image": "", "description": ""}
          ]
        },
        {
          "name": "腾讯新闻", "icon": "tx", "color": "#00bcf0", "category": "新闻", "key": "tengxun",
          "items": [
            {"id": "r1", "rank": 1, "title": "腾讯热一", "url": "https://view.inews.qq.com/a/1",
             "heat": "44万评论", "image": "", "description": ""}
          ]
        },
        {
          "name": "微博", "icon": "wb", "color": "#ff5722", "category": "社区", "key": "weibo",
          "items": [
            {"id": "r1", "rank": 1, "title": "微博热一", "url": "https://s.weibo.com/1",
             "heat": "", "image": "", "description": ""}
          ]
        }
      ]
    }
    """

    private func decodedSources() throws -> [RemoShuangHot.Source] {
        try RemoShuangHot.decodeSources(from: Data(sampleJSON.utf8))
    }

    func testDecodeEnvelope() throws {
        let sources = try decodedSources()
        XCTAssertEqual(sources.count, 3)
        XCTAssertEqual(sources[0].key, "zhihu")
        XCTAssertEqual(sources[0].category, "社区")
        XCTAssertEqual(sources[0].items.count, 2)
        XCTAssertEqual(sources[0].items[0].rank, 1)
    }

    func testCategoryLabelsInFirstSeenOrder() throws {
        let sources = try decodedSources()
        XCTAssertEqual(RemoShuangHot.categoryLabels(of: sources), ["社区", "新闻"])
    }

    func testCombinedEntriesRoundRobinByRankThenHeat() throws {
        let sources = try decodedSources()
        let entries = RemoShuangHot.entries(from: sources, categoryLabel: nil)

        // 第 1 轮（各来源 rank 1）：知乎(8000万) > 腾讯(44万) > 微博(无热度)
        // 第 2 轮：只剩知乎 rank 2
        XCTAssertEqual(
            entries.map(\.title),
            ["知乎热一", "腾讯热一", "微博热一", "知乎热二"]
        )
        XCTAssertEqual(entries[0].sourceName, "知乎")
        XCTAssertEqual(entries[0].link?.absoluteString, "https://www.zhihu.com/q/1")
        XCTAssertEqual(entries[0].id, "zhihu-r1")
    }

    func testCategoryFilter() throws {
        let sources = try decodedSources()
        let entries = RemoShuangHot.entries(from: sources, categoryLabel: "新闻")
        XCTAssertEqual(entries.map(\.title), ["腾讯热一"])
        XCTAssertEqual(entries.map(\.sourceName), ["腾讯新闻"])
    }

    func testHeatValueParsing() {
        XCTAssertEqual(RemoShuangHot.heatValue("17201 万热度"), 172_010_000)
        XCTAssertEqual(RemoShuangHot.heatValue("44万评论"), 440_000)
        XCTAssertEqual(RemoShuangHot.heatValue("241回复"), 241)
        XCTAssertEqual(RemoShuangHot.heatValue(""), 0)
        XCTAssertEqual(RemoShuangHot.heatValue("热议中"), 0)
    }

    func testEntryCodableRoundTrip() throws {
        let sources = try decodedSources()
        let entries = RemoShuangHot.entries(from: sources, categoryLabel: nil)
        let data = try JSONEncoder().encode(entries)
        let again = try JSONDecoder().decode([RemoShuangHot.Entry].self, from: data)
        XCTAssertEqual(again.map(\.id), entries.map(\.id))
    }
}
