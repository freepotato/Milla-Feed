import XCTest
@testable import MillaCore

final class SwiftFeedParserTests: XCTestCase {

    private let source = FeedSource(
        id: UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!,
        title: "Test",
        url: URL(string: "https://example.com/feed.xml")!
    )

    private func parse(_ xml: String) throws -> ParsedFeed {
        try SwiftFeedParser().parse(
            data: Data(xml.utf8),
            source: source
        )
    }

    func testParsesRSS2WithCDATAAndMediaContent() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <rss version="2.0" xmlns:content="http://purl.org/rss/1.0/modules/content/"
             xmlns:media="http://search.yahoo.com/mrss/" xmlns:dc="http://purl.org/dc/elements/1.1/">
          <channel>
            <title>Example Feed</title>
            <link>https://example.com</link>
            <item>
              <title>Hello &amp; Goodbye</title>
              <link>https://example.com/post/1</link>
              <guid>post-1</guid>
              <pubDate>Sun, 11 Oct 2026 09:30:00 GMT</pubDate>
              <dc:creator>Jane Doe</dc:creator>
              <media:content url="https://example.com/cover.jpg" medium="image" type="image/jpeg" width="1200"/>
              <description><![CDATA[<p>Short <b>summary</b> text.</p>]]></description>
              <content:encoded><![CDATA[<p>Full body &amp; details here.</p>]]></content:encoded>
            </item>
          </channel>
        </rss>
        """

        let feed = try parse(xml)
        XCTAssertEqual(feed.title, "Example Feed")
        XCTAssertEqual(feed.items.count, 1)

        let item = try XCTUnwrap(feed.items.first)
        XCTAssertEqual(item.title, "Hello & Goodbye")
        XCTAssertEqual(item.link?.absoluteString, "https://example.com/post/1")
        XCTAssertEqual(item.author, "Jane Doe")
        XCTAssertEqual(item.imageURL?.absoluteString, "https://example.com/cover.jpg")
        XCTAssertEqual(item.summary, "Short summary text.")
        // CDATA 内容按 XML 语义原样保留，实体留给 HTML 渲染层解码
        XCTAssertTrue(item.contentHTML.contains("Full body &amp; details here."))
        XCTAssertNotNil(item.publishedAt)
        XCTAssertEqual(
            item.id,
            StableIdentifier.make([source.id.uuidString, "post-1"])
        )
    }

    func testParsesAtomFeed() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <feed xmlns="http://www.w3.org/2005/Atom">
          <title>Atom Example</title>
          <entry>
            <title>Atom Entry</title>
            <id>tag:example.com,2026:1</id>
            <link rel="alternate" href="https://example.com/atom/1"/>
            <link rel="edit" href="https://example.com/edit/1"/>
            <published>2026-10-11T08:00:00Z</published>
            <updated>2026-10-11T09:00:00Z</updated>
            <author><name>John</name></author>
            <content type="html">&lt;p&gt;Body with &lt;img src="https://example.com/a.png"&gt;&lt;/p&gt;</content>
          </entry>
        </feed>
        """

        let feed = try parse(xml)
        XCTAssertEqual(feed.title, "Atom Example")
        let item = try XCTUnwrap(feed.items.first)
        XCTAssertEqual(item.title, "Atom Entry")
        XCTAssertEqual(item.link?.absoluteString, "https://example.com/atom/1")
        XCTAssertEqual(item.author, "John")
        XCTAssertEqual(item.imageURL?.absoluteString, "https://example.com/a.png")
        XCTAssertEqual(item.summary, "Body with")
        XCTAssertNotNil(item.publishedAt)
    }

    func testEnclosureImageAndHTMLEntities() throws {
        let xml = """
        <rss version="2.0"><channel><title>X</title>
          <item>
            <title>&#x4E2D;&#x6587; Title &#8212; Test</title>
            <link>https://example.com/p</link>
            <enclosure url="https://example.com/p.webp" length="1024" type="image/webp"/>
            <description>Plain &quot;quoted&quot; line.&lt;br&gt;Second</description>
          </item>
        </channel></rss>
        """
        let feed = try parse(xml)
        let item = try XCTUnwrap(feed.items.first)
        XCTAssertEqual(item.title, "中文 Title — Test")
        XCTAssertEqual(item.imageURL?.absoluteString, "https://example.com/p.webp")
        XCTAssertTrue(item.summary.contains("\"quoted\""))
    }

    func testInvalidInputThrows() {
        let source = self.source
        XCTAssertThrowsError(
            try SwiftFeedParser().parse(data: Data("not a feed at all".utf8), source: source)
        ) { error in
            XCTAssertEqual(error as? FeedParseError, FeedParseError.notAFeed)
        }
    }

    func testHTMLPlainTextAndImageExtraction() {
        let html = """
        <div><h1>Headline</h1><p>Body&nbsp;text <a href="x">link</a></p>
        <script>alert(1)</script><img src="https://img.example.com/x.jpg" alt="x"></div>
        """
        let text = HTMLText.plainText(from: html)
        XCTAssertTrue(text.contains("Headline"))
        XCTAssertTrue(text.contains("Body text link"))
        XCTAssertFalse(text.contains("alert"))
        XCTAssertEqual(
            HTMLText.firstImageURL(in: html)?.absoluteString,
            "https://img.example.com/x.jpg"
        )
    }
}
