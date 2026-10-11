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

    // MARK: 重复导入语

    func testRemovesRepeatedIntroKeepingSourceLine() {
        let intro = "每一个家长都会有这么一天：孩子在外边被人打了，我怎么办？自闭症孩子的家长则更加卑微"
        let html = """
        <figure><img src="https://x.com/cover.jpg"/></figure>
        <p>\(intro)</p>
        <p>本文来自微信公众号：大米和小米 编辑：苏渡 作者：特殊孩子保护</p>
        <p>\(intro)</p>
        <p>这是后续正文内容，和前面完全不同的一段文字用于确保不会误删。</p>
        """
        let out = ContentSanitizer.sanitize(html)
        let prefix = String(intro.prefix(30))
        XCTAssertEqual(
            out.components(separatedBy: prefix).count - 1, 1,
            "开头导入语应只保留正文那一份: \(out)"
        )
        XCTAssertTrue(out.contains("本文来自微信公众号"), "来源行应保留")
        XCTAssertTrue(out.contains("这是后续正文内容"))
        XCTAssertTrue(out.contains("<img"), "封面 figure 不应被导入语逻辑误删")
    }

    func testKeepsIntroWhenNotRepeated() {
        let intro = "这是文章独有的开头段落，在全文任何其他位置都不会再次出现的一段文字。"
        let html = """
        <p>\(intro)</p>
        <p>后续段落一，讲述\(String(repeating: "具体细节内容", count: 20))。</p>
        <p>后续段落二，\(String(repeating: "继续展开论述", count: 20))。</p>
        """
        let out = ContentSanitizer.sanitize(html)
        XCTAssertTrue(out.contains("这是文章独有的开头段落"), "未重复的开头不应被删除")
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
