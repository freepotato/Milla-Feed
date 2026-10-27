import XCTest
@testable import MillaCore

/// 末尾"查看全文"链接的保留规则（ContentSanitizer 的链接剥离例外）。
final class ContentSanitizerReadMoreTests: XCTestCase {

    func testTrailingReadMoreLinkIsKept() {
        let html = """
        <p>\(String(repeating: "正", count: 260))</p>\
        <p><a href="https://example.com/full">查看全文</a></p>
        """
        let out = ContentSanitizer.sanitize(html)
        XCTAssertTrue(out.contains("<a href=\"https://example.com/full\">查看全文</a>"), out)
    }

    func testTrailingReadMoreWrappedInNakedTextIsKept() {
        // 有的源末尾是裸 <a> 不带 <p> 包裹
        let html = """
        <p>\(String(repeating: "正", count: 260))</p>\
        <a href="https://example.com/full">阅读原文</a>
        """
        let out = ContentSanitizer.sanitize(html)
        XCTAssertTrue(out.contains("<a href=\"https://example.com/full\">阅读原文</a>"), out)
    }

    func testMidArticleLinkIsUnwrapped() {
        let html = """
        <p>\(String(repeating: "正", count: 260))<a href="https://example.com/a">相关报道</a>继续。</p>\
        <p><a href="https://example.com/full">查看全文</a></p>
        """
        let out = ContentSanitizer.sanitize(html)
        // 文中链接只留文字
        XCTAssertFalse(out.contains("example.com/a"), out)
        XCTAssertTrue(out.contains("相关报道"), out)
        // 末尾查看全文保留
        XCTAssertTrue(out.contains("<a href=\"https://example.com/full\">查看全文</a>"), out)
    }

    func testTrailingOrdinaryLinkIsUnwrapped() {
        let html = """
        <p>\(String(repeating: "正", count: 260))</p>\
        <p><a href="https://example.com/other">某某官网</a></p>
        """
        let out = ContentSanitizer.sanitize(html)
        XCTAssertFalse(out.contains("<a"), out)
    }

    func testReadMoreFarFromEndIsUnwrapped() {
        // "查看全文"出现在正文中间（后面还有大段正文），不算末尾链接
        let html = """
        <p><a href="https://example.com/full">查看全文</a></p>\
        <p>\(String(repeating: "正", count: 300))</p>
        """
        let out = ContentSanitizer.sanitize(html)
        XCTAssertFalse(out.contains("<a"), out)
        XCTAssertTrue(out.contains("查看全文"), out)
    }

    func testAnchorWrappingImageKeepsImage() {
        let html = """
        <p>\(String(repeating: "正", count: 260))</p>\
        <p><a href="https://example.com/x"><img src="https://example.com/pic.png"></a></p>
        """
        let out = ContentSanitizer.sanitize(html)
        XCTAssertFalse(out.contains("<a"), out)
        XCTAssertTrue(out.contains("<img src=\"https://example.com/pic.png\">"), out)
    }
}
