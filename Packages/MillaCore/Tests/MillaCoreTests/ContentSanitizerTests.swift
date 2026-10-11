import XCTest
@testable import MillaCore

final class ContentSanitizerTests: XCTestCase {

    // MARK: Hacker News 样板段落

    func testRemovesHNBoilerplate() {
        let html = """
        <p>Article URL: <a href="https://ircv3.net/">https://ircv3.net/</a></p>
        <p>Comments URL: <a href="https://news.ycombinator.com/item?id=1">https://news.ycombinator.com/item?id=1</a></p>
        <p>Points: 18</p>
        <p># Comments: 0</p>
        """
        let out = ContentSanitizer.sanitize(html)
        XCTAssertFalse(out.contains("Article URL"))
        XCTAssertFalse(out.contains("Points"))
        XCTAssertTrue(out.trimmingCharacters(in: .whitespaces).isEmpty)
    }

    // MARK: 导航 / 页脚元素块

    func testRemovesNavigationAndFooterBlocks() {
        let html = """
        <div class="hds-secondary-navigation wp-block-nav"><button>APOD</button><svg><path d="m1"/></svg><span>Science</span></div>
        <p>\(String(repeating: "这是正文内容。", count: 40))</p>
        <div class="site-footer"><a href="https://x.com/">Today's APOD</a> <a href="https://x.com/">Archive</a> <a href="https://x.com/">Submissions</a></div>
        """
        let out = ContentSanitizer.sanitize(html)
        XCTAssertFalse(out.contains("APOD"), "导航残渣应被移除: \(out)")
        XCTAssertFalse(out.contains("Submissions"), "页脚链接应被移除: \(out)")
        XCTAssertFalse(out.contains("<button"))
        XCTAssertFalse(out.contains("<svg"))
        XCTAssertTrue(out.contains("这是正文内容。"))
        XCTAssertFalse(out.contains("<a "), "正文不应残留超链接标签")
    }

    // MARK: 超链接剥离（保留文字）

    func testUnwrapsAnchorsKeepingText() {
        let html = "<p>See \(String(repeating: "the report details here. ", count: 12))" +
            "<a href=\"https://x.com/\" class=\"link\">section two</a> for more context.</p>"
        let out = ContentSanitizer.sanitize(html)
        XCTAssertFalse(out.contains("<a"))
        XCTAssertFalse(out.contains("</a>"))
        XCTAssertTrue(out.contains("section two"))
    }

    // MARK: 短正文守卫（不误删唯一段落）

    func testKeepsShortSingleParagraph() {
        let html = "<p>Full body &amp; details here.</p>"
        XCTAssertEqual(ContentSanitizer.sanitize(html), "<p>Full body &amp; details here.</p>")
    }

    // MARK: 封面同图去重

    func testRemovingImageMatchingCover() {
        let html = """
        <figure><img src="https://x.com/cover.jpg?quality=90" alt="cover"/></figure>
        <p>\(String(repeating: "正文段落。", count: 50))</p>
        <p><img src="https://x.com/other.jpg" alt="inline"/></p>
        """
        let out = ContentSanitizer.removingImage(
            from: html,
            matching: URL(string: "https://x.com/cover.jpg?quality=90")!
        )
        XCTAssertFalse(out.contains("cover.jpg"), "与封面同图的 img 应被删除")
        XCTAssertTrue(out.contains("other.jpg"), "正文其他图片应保留")
    }
}
