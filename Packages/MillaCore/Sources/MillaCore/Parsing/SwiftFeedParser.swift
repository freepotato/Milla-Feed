import Foundation

/// 纯 Swift 的 RSS 2.0 / Atom 解析器。
///
/// 设计目标：
/// - 只依赖 Foundation，可运行在 Windows / Linux 的开源 Swift 工具链上；
/// - 处理 CDATA、HTML/XML 实体、命名空间元素（content:encoded、dc:creator、
///   media:content / media:thumbnail、Atom entry）；
/// - iOS 端优先使用系统 `XMLParser`，本实现作为跨平台兜底与测试基准。
public final class SwiftFeedParser: FeedParsing, @unchecked Sendable {

    public init() {}

    public func parse(data: Data, source: FeedSource) throws -> ParsedFeed {
        guard let text = String(data: data, encoding: .utf8)
            ?? String(data: data, encoding: .isoLatin1) else {
            throw FeedParseError.invalidEncoding
        }

        let tokens = XMLTokenizer.tokenize(text)
        let builder = FeedTreeBuilder(source: source)
        builder.consume(tokens)

        guard builder.sawFeedRoot else {
            throw FeedParseError.notAFeed
        }
        return ParsedFeed(
            title: builder.feedTitle,
            siteURL: builder.feedSiteURL,
            items: builder.items
        )
    }
}

// MARK: - Token

enum XMLToken {
    case startElement(name: String, attributes: [String: String], selfClosing: Bool)
    case endElement(name: String)
    case text(String)
}

// MARK: - Tokenizer

enum XMLTokenizer {

    static func tokenize(_ input: String) -> [XMLToken] {
        var tokens: [XMLToken] = []
        let scalars = input.unicodeScalars
        var index = scalars.startIndex

        func startsWith(_ literal: String) -> Bool {
            var i = index
            for ch in literal.unicodeScalars {
                guard i < scalars.endIndex, scalars[i] == ch else { return false }
                scalars.formIndex(after: &i)
            }
            return true
        }

        func scan(until terminators: String, consumeTerminator: Bool = true) -> String {
            let start = index
            while index < scalars.endIndex {
                if terminators.unicodeScalars.contains(scalars[index]) { break }
                scalars.formIndex(after: &index)
            }
            let content = String(String.UnicodeScalarView(scalars[start..<index]))
            if consumeTerminator, index < scalars.endIndex {
                scalars.formIndex(after: &index)
            }
            return content
        }

        while index < scalars.endIndex {
            let scalar = scalars[index]

            if scalar != "<" {
                var text = ""
                while index < scalars.endIndex, scalars[index] != "<" {
                    text.append(Character(scalars[index]))
                    scalars.formIndex(after: &index)
                }
                let decoded = HTMLText.decodeEntities(in: text)
                if decoded.trimmingCharacters(in: .whitespacesAndNewlines).isNotEmpty {
                    tokens.append(.text(decoded))
                }
                continue
            }

            // 注释
            if startsWith("<!--") {
                index = scalars.index(index, offsetBy: 4)
                while index < scalars.endIndex, !startsWith("-->") {
                    scalars.formIndex(after: &index)
                }
                if index < scalars.endIndex {
                    index = scalars.index(index, offsetBy: 3)
                }
                continue
            }

            // CDATA
            if startsWith("<![CDATA[") {
                index = scalars.index(index, offsetBy: 9)
                let start = index
                while index < scalars.endIndex, !startsWith("]]>") {
                    scalars.formIndex(after: &index)
                }
                let cdata = String(String.UnicodeScalarView(scalars[start..<index]))
                if index < scalars.endIndex {
                    index = scalars.index(index, offsetBy: 3)
                }
                if cdata.trimmingCharacters(in: .whitespacesAndNewlines).isNotEmpty {
                    tokens.append(.text(cdata))
                }
                continue
            }

            // DOCTYPE / 声明
            if startsWith("<!") || startsWith("<?") {
                _ = scan(until: ">")
                continue
            }

            // 普通元素
            scalars.formIndex(after: &index) // 跳过 "<"
            let rawTag = scan(until: ">")
            tokens.append(contentsOf: parseTag(rawTag))
        }

        return tokens
    }

    private static func parseTag(_ raw: String) -> [XMLToken] {
        var tag = raw.trimmingCharacters(in: .whitespaces)
        guard !tag.isEmpty else { return [] }

        let isClosing = tag.hasPrefix("/")
        if isClosing { tag.removeFirst() }

        let selfClosing = tag.hasSuffix("/")
        if selfClosing { tag.removeLast() }
        tag = tag.trimmingCharacters(in: .whitespaces)

        // 分离元素名与属性
        var name = ""
        var index = tag.unicodeScalars.startIndex
        while index < tag.unicodeScalars.endIndex {
            let ch = tag.unicodeScalars[index]
            if ch == " " || ch == "\t" || ch == "\n" || ch == "/" { break }
            name.append(Character(ch))
            tag.unicodeScalars.formIndex(after: &index)
        }
        let attributesRaw = String(tag.unicodeScalars[index...])
        let attributes = parseAttributes(attributesRaw)

        name = name.trimmingCharacters(in: .whitespaces).lowercased()
        guard !name.isEmpty else { return [] }

        if isClosing {
            return [.endElement(name: name)]
        }
        return [.startElement(name: name, attributes: attributes, selfClosing: selfClosing)]
    }

    private static func parseAttributes(_ raw: String) -> [String: String] {
        var attributes: [String: String] = [:]
        let scalars = raw.unicodeScalars
        var index = scalars.startIndex

        while index < scalars.endIndex {
            // 跳过空白
            while index < scalars.endIndex,
                  scalars[index] == " " || scalars[index] == "\t" || scalars[index] == "\n" {
                scalars.formIndex(after: &index)
            }
            guard index < scalars.endIndex else { break }

            // 属性名
            let nameStart = index
            while index < scalars.endIndex, scalars[index] != "=" {
                if scalars[index] == " " || scalars[index] == ">" { break }
                scalars.formIndex(after: &index)
            }
            let name = String(String.UnicodeScalarView(scalars[nameStart..<index]))
                .trimmingCharacters(in: .whitespaces).lowercased()

            // 跳到 =
            while index < scalars.endIndex, scalars[index] != "=" {
                scalars.formIndex(after: &index)
            }
            guard index < scalars.endIndex else { break }
            scalars.formIndex(after: &index) // =

            while index < scalars.endIndex,
                  scalars[index] == " " || scalars[index] == "\t" || scalars[index] == "\n" {
                scalars.formIndex(after: &index)
            }
            guard index < scalars.endIndex else { break }

            let quote = scalars[index]
            guard quote == "'" || quote == "\"" else { break }
            scalars.formIndex(after: &index)

            let valueStart = index
            while index < scalars.endIndex, scalars[index] != quote {
                scalars.formIndex(after: &index)
            }
            let value = String(String.UnicodeScalarView(scalars[valueStart..<index]))
            if index < scalars.endIndex { scalars.formIndex(after: &index) }

            if !name.isEmpty {
                attributes[name] = HTMLText.decodeEntities(in: value)
            }
        }
        return attributes
    }
}

private extension String {
    var isNotEmpty: Bool { !isEmpty }
}

// MARK: - Tree builder (RSS 2.0 + Atom)

private final class FeedTreeBuilder {

    private let source: FeedSource

    private(set) var sawFeedRoot = false
    private(set) var feedTitle: String?
    private(set) var feedSiteURL: URL?
    private(set) var items: [FeedItem] = []

    private var stack: [String] = []

    // 当前 item/entry 的累积字段
    private var box: Box?
    private var capturingLeaf: String?
    private var captureBuffer = ""

    // channel/feed 级别
    private var channelLeaf: String?
    private var channelBuffer = ""

    private final class Box {
        var fields: [String: String] = [:]
        var mediaURL: String?
        var atomLinks: [(rel: String?, href: String)] = []
    }

    init(source: FeedSource) {
        self.source = source
    }

    func consume(_ tokens: [XMLToken]) {
        for token in tokens {
            switch token {
            case .startElement(let name, let attributes, let selfClosing):
                handleStart(name: name, attributes: attributes)
                if selfClosing { handleEnd(name: name) }
            case .endElement(let name):
                handleEnd(name: name)
            case .text(let text):
                handleText(text)
            }
        }
    }

    // MARK: Start

    private func handleStart(name: String, attributes: [String: String]) {
        stack.append(name)

        switch name {
        case "rss", "feed", "rdf:rdf":
            sawFeedRoot = true
        case "channel":
            break
        case "item", "entry":
            box = Box()
        default:
            break
        }

        if let box {
            // 结构性属性：封面图 / Atom 链接
            switch name {
            case "enclosure":
                if let url = attributes["url"], isImageType(attributes["type"], url: url) {
                    box.mediaURL = box.mediaURL ?? url
                }
            case "media:content", "media:thumbnail":
                if let url = attributes["url"],
                   box.mediaURL == nil,
                   isImageType(attributes["type"], url: url) {
                    box.mediaURL = url
                }
            case "link" where isAtom:
                if let href = attributes["href"] {
                    box.atomLinks.append((attributes["rel"], href))
                }
            default:
                break
            }

            // 开始收集叶子文本（title/description/content:encoded 等）
            if capturingLeaf == nil, isCapturedLeaf(name) {
                capturingLeaf = name
                captureBuffer = ""
            }
        } else if sawFeedRoot, channelLeaf == nil, isChannelLeaf(name) {
            channelLeaf = name
            channelBuffer = ""
        }
    }

    // MARK: End

    private func handleEnd(name: String) {
        if let leaf = capturingLeaf, leaf == name, box != nil {
            box?.fields[leaf] = box?.fields[leaf].map { $0 + captureBuffer } ?? captureBuffer
            capturingLeaf = nil
            captureBuffer = ""
        }

        if let leaf = channelLeaf, leaf == name, box == nil {
            switch leaf {
            case "title":
                feedTitle = channelBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
            case "link" where !isAtom:
                feedSiteURL = URL(string: channelBuffer.trimmingCharacters(in: .whitespaces))
            default:
                break
            }
            channelLeaf = nil
            channelBuffer = ""
        }

        if (name == "item" || name == "entry"), let current = box {
            items.append(makeItem(from: current))
            box = nil
            capturingLeaf = nil
            captureBuffer = ""
        }

        if name == "link", isAtom, box == nil, feedSiteURL == nil {
            // Atom feed 级链接在 handleStart 中无法直接拿到结束事件配对，
            // 这里借助已累积的 channelBuffer 不适用，因此忽略，站点链接非必需。
        }

        if !stack.isEmpty { stack.removeLast() }
    }

    // MARK: Text

    private func handleText(_ text: String) {
        if capturingLeaf != nil, box != nil {
            captureBuffer += text
        } else if channelLeaf != nil, box == nil {
            channelBuffer += text
        }
    }

    // MARK: Build item

    private func makeItem(from box: Box) -> FeedItem {
        let fields = box.fields

        let title = HTMLText.plainText(
            from: fields["title"] ?? "",
            maximumLength: 500
        )

        let link = resolveLink(fields: fields, box: box)

        let rawDescription = fields["description"]
            ?? fields["itunes:summary"]
            ?? fields["summary"]
            ?? ""
        let contentHTML = fields["content:encoded"]
            ?? (fields["content"] ?? "")

        let imageURL = box.mediaURL
            .flatMap(URL.init(string:))
            ?? HTMLText.firstImageURL(in: contentHTML)
            ?? HTMLText.firstImageURL(in: rawDescription)

        let summary: String = {
            let base = rawDescription.isNotEmpty ? rawDescription : contentHTML
            return HTMLText.plainText(from: base, maximumLength: 240)
        }()

        let author = fields["dc:creator"]
            ?? fields["name"]
            ?? fields["author"]
            ?? fields["itunes:author"]

        let dateString = fields["pubdate"]
            ?? fields["dc:date"]
            ?? fields["published"]
            ?? fields["updated"]
            ?? fields["date"]
        let publishedAt = dateString.flatMap { FeedDateParser.date(from: $0) }

        let guid = fields["guid"] ?? fields["id"]
        let identity = guid ?? link?.absoluteString ?? title
        let stableID = StableIdentifier.make([source.id.uuidString, identity])

        return FeedItem(
            id: stableID,
            sourceID: source.id,
            title: title,
            link: link,
            summary: summary,
            contentHTML: contentHTML,
            imageURL: imageURL,
            author: author?.trimmingCharacters(in: .whitespacesAndNewlines),
            publishedAt: publishedAt
        )
    }

    private func resolveLink(fields: [String: String], box: Box) -> URL? {
        // Atom：优先 rel="alternate"（或无 rel）；atomLinks 只在 Atom 下累积
        if let alternate = box.atomLinks.first(where: { $0.rel == nil || $0.rel == "alternate" })
            ?? box.atomLinks.first,
           let url = URL(string: alternate.href) {
            return url
        }
        // RSS 2.0：<link>文本</link>
        // 注意先判空：部分平台（swift-corelibs-foundation）URL(string: "") 会返回非 nil 的空 URL
        let text = fields["link"]?.trimmingCharacters(in: .whitespaces) ?? ""
        if !text.isEmpty, let url = URL(string: text) {
            return url
        }
        return nil
    }

    // MARK: Helpers

    private var isAtom: Bool {
        stack.first == "feed"
    }

    private func isCapturedLeaf(_ name: String) -> Bool {
        switch name {
        // 注意：标签名在分词器中已统一转为小写。
        case "title", "link", "description", "author", "category", "comments",
             "guid", "pubdate", "date", "source",
             "content:encoded", "content", "summary",
             "dc:creator", "dc:date", "name",
             "published", "updated", "id",
             "itunes:author", "itunes:summary":
            return true
        default:
            return false
        }
    }

    private func isChannelLeaf(_ name: String) -> Bool {
        name == "title" || name == "link" || name == "description"
    }

    private func isImageType(_ type: String?, url: String) -> Bool {
        if let type, type.hasPrefix("image/") { return true }
        if let type, type.isEmpty { return false }
        let lowerURL = url.lowercased()
        let imageExtensions = [".jpg", ".jpeg", ".png", ".gif", ".webp", ".avif", ".heic"]
        return imageExtensions.contains { lowerURL.contains($0) }
    }
}
