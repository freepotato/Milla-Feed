import Foundation
import MillaCore

/// 基于 Apple 原生 `XMLParser`（NSXMLParser）的 RSS 2.0 / Atom 解析器。
/// iOS App 的首选实现；解析失败时由 FeedSyncService 回退到纯 Swift 的 `SwiftFeedParser`。
final class XMLParserFeedParser: NSObject, FeedParsing {

    func parse(data: Data, source: FeedSource) throws -> ParsedFeed {
        let delegate = ParserDelegate(source: source)
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        parser.shouldProcessNamespaces = false
        parser.shouldReportNamespacePrefixes = false
        parser.shouldResolveExternalEntities = false

        guard parser.parse(), delegate.sawFeedRoot else {
            throw parser.parserError ?? FeedParseError.notAFeed
        }
        return ParsedFeed(
            title: delegate.feedTitle,
            siteURL: nil,
            items: delegate.items
        )
    }
}

private final class ParserDelegate: NSObject, XMLParserDelegate {

    let source: FeedSource
    private(set) var sawFeedRoot = false
    private(set) var feedTitle: String?
    private(set) var items: [FeedItem] = []

    private var currentText = ""
    private var currentItem: [String: String] = [:]
    private var mediaURL: String?
    private var atomLinks: [(rel: String?, href: String)] = []
    private var depthInItem = 0
    private var capturingChannelTitle = false

    init(source: FeedSource) {
        self.source = source
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        let name = elementName.lowercased()

        switch name {
        case "rss", "feed", "rdf:rdf":
            sawFeedRoot = true

        case "item", "entry":
            depthInItem += 1
            currentItem = [:]
            mediaURL = nil
            atomLinks = []

        case "channel":
            break

        default:
            if depthInItem > 0 {
                handleItemStart(name: name, attributes: attributeDict)
            } else if name == "title" {
                capturingChannelTitle = true
                currentText = ""
            }
        }

        if depthInItem > 0 || capturingChannelTitle {
            currentText = ""
        }
    }

    private func handleItemStart(name: String, attributes: [String: String]) {
        switch name {
        case "enclosure":
            if let url = attributes["url"], isImageType(attributes["type"], url: url) {
                mediaURL = mediaURL ?? url
            }
        case "media:content", "media:thumbnail":
            if let url = attributes["url"], mediaURL == nil,
               isImageType(attributes["type"], url: url) {
                mediaURL = url
            }
        case "link" where attributes["href"] != nil:
            // Atom 链接：属性形式
            atomLinks.append((attributes["rel"], attributes["href"]!))
        default:
            break
        }
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        let name = elementName.lowercased()
        let text = currentText.trimmingCharacters(in: .whitespacesAndNewlines)

        if depthInItem > 0 {
            switch name {
            case "item", "entry":
                depthInItem -= 1
                if depthInItem == 0 {
                    items.append(makeItem())
                    currentItem = [:]
                    mediaURL = nil
                    atomLinks = []
                }
            case "link" where text.hasPrefix("http"):
                // RSS 2.0 文本形式链接
                currentItem["link"] = text
            default:
                if capturedLeafNames.contains(name), currentItem[name] == nil {
                    currentItem[name] = text
                }
            }
        } else if name == "title", capturingChannelTitle {
            feedTitle = text
            capturingChannelTitle = false
        }
        currentText = ""
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string
    }

    func parser(
        _ parser: XMLParser,
        foundCDATA CDATABlock: Data
    ) {
        if let string = String(data: CDATABlock, encoding: .utf8) {
            currentText += string
        }
    }

    // MARK: Build

    private let capturedLeafNames: Set<String> = [
        "title", "description", "author", "guid", "pubdate", "date",
        "content:encoded", "content", "summary",
        "dc:creator", "dc:date", "name",
        "published", "updated", "id",
        "itunes:author", "itunes:summary"
    ]

    private func makeItem() -> FeedItem {
        let title = HTMLText.plainText(from: currentItem["title"] ?? "", maximumLength: 500)
        let link = resolveLink()
        let rawDescription = currentItem["description"]
            ?? currentItem["itunes:summary"]
            ?? currentItem["summary"]
            ?? ""
        let rawContent = currentItem["content:encoded"] ?? currentItem["content"] ?? ""

        // 正文净化：去原网页导航/页脚/样板噪声与超链接，与 SwiftFeedParser 行为一致
        let sanitizedContent = ContentSanitizer.sanitize(rawContent)
        let sanitizedDescription = ContentSanitizer.sanitize(rawDescription)
        let contentHTML = sanitizedContent.isEmpty ? sanitizedDescription : sanitizedContent

        let imageURL = mediaURL.flatMap(URL.init(string:))
            ?? HTMLText.firstImageURL(in: contentHTML)

        let summary = HTMLText.plainText(
            from: sanitizedDescription.isEmpty ? contentHTML : sanitizedDescription,
            maximumLength: 240
        )

        let author = currentItem["dc:creator"]
            ?? currentItem["name"]
            ?? currentItem["author"]
            ?? currentItem["itunes:author"]

        let dateString = currentItem["pubdate"]
            ?? currentItem["dc:date"]
            ?? currentItem["published"]
            ?? currentItem["updated"]
            ?? currentItem["date"]

        let guid = currentItem["guid"] ?? currentItem["id"]
        let identity = guid ?? link?.absoluteString ?? title

        return FeedItem(
            id: StableIdentifier.make([source.id.uuidString, identity]),
            sourceID: source.id,
            title: title,
            link: link,
            summary: summary,
            contentHTML: contentHTML,
            imageURL: imageURL,
            author: author,
            publishedAt: dateString.flatMap { FeedDateParser.date(from: $0) }
        )
    }

    private func resolveLink() -> URL? {
        if let rss = currentItem["link"].flatMap(URL.init(string:)) {
            return rss
        }
        let alternate = atomLinks.first { $0.rel == nil || $0.rel == "alternate" }
            ?? atomLinks.first
        return alternate.flatMap { URL(string: $0.href) }
    }

    private func isImageType(_ type: String?, url: String) -> Bool {
        if let type, type.hasPrefix("image/") { return true }
        if let type, !type.isEmpty { return false }
        let lowerURL = url.lowercased()
        return [".jpg", ".jpeg", ".png", ".gif", ".webp", ".avif", ".heic"]
            .contains { lowerURL.contains($0) }
    }
}
