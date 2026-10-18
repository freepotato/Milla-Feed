import XCTest
@testable import MillaCore

final class RemoShuangTodayTests: XCTestCase {

    /// 接口真实字段的子集：解码应忽略未建模的字段（position、firstSeenAt 等）。
    private let sampleJSON = """
    {
      "success": true,
      "available": true,
      "date": "2026-10-18",
      "generatedAt": "2026-10-18T10:30:01.527Z",
      "total": 60,
      "top": [
        {
          "eventId": "2026-10-19:hot-10",
          "slug": "20261019-56ba51e9",
          "title": "DeepSeek 新版本发布",
          "summary": "DeepSeek 新版本发布",
          "category": "科技",
          "sourceCount": 4,
          "sourceNames": ["IT之家", "知乎"],
          "href": "/event/20261019-56ba51e9",
          "external": false,
          "firstSeenAt": "2026-10-17T21:20:04.624Z",
          "position": 10,
          "date": "2026-10-19"
        }
      ],
      "sections": [
        {
          "key": "tech",
          "label": "科技",
          "items": [
            {
              "eventId": "2026-10-19:tech-1",
              "slug": "abc",
              "title": "某科技新闻",
              "summary": "",
              "category": "科技",
              "sourceCount": 2,
              "sourceNames": ["36氪"],
              "href": "/event/abc",
              "external": false
            }
          ]
        },
        { "key": "finance", "label": "财经", "items": [] }
      ]
    }
    """

    func testDecodesRealPayloadShape() throws {
        let decoded = try JSONDecoder().decode(
            RemoShuangToday.self,
            from: Data(sampleJSON.utf8)
        )

        XCTAssertEqual(decoded.date, "2026-10-18")
        XCTAssertEqual(decoded.top.count, 1)
        XCTAssertEqual(decoded.sections.count, 2)

        let event = decoded.top[0]
        XCTAssertEqual(event.id, "2026-10-19:hot-10")
        XCTAssertEqual(event.title, "DeepSeek 新版本发布")
        XCTAssertEqual(event.sourceCount, 4)
        XCTAssertEqual(
            event.eventURL?.absoluteString,
            "https://remoshuang.com/event/20261019-56ba51e9"
        )

        XCTAssertEqual(decoded.sections[0].label, "科技")
        XCTAssertEqual(decoded.sections[0].items.first?.id, "2026-10-19:tech-1")
    }

    func testRoundTripPreservesData() throws {
        let decoded = try JSONDecoder().decode(
            RemoShuangToday.self,
            from: Data(sampleJSON.utf8)
        )
        let reencoded = try JSONEncoder().encode(decoded)
        let again = try JSONDecoder().decode(RemoShuangToday.self, from: reencoded)
        XCTAssertEqual(again.top.map(\.id), decoded.top.map(\.id))
        XCTAssertEqual(again.sections.map(\.key), decoded.sections.map(\.key))
    }
}
