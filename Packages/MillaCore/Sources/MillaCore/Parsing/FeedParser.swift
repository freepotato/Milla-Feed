import Foundation

/// 解析结果：订阅源元信息 + 内容条目。
public struct ParsedFeed: Equatable, Sendable {
    public var title: String?
    public var siteURL: URL?
    public var items: [FeedItem]

    public init(title: String?, siteURL: URL?, items: [FeedItem]) {
        self.title = title
        self.siteURL = siteURL
        self.items = items
    }
}

/// RSS 解析器抽象。
///
/// - iOS App 默认使用基于 Apple `XMLParser` 的实现（见 App target `XMLParserFeedParser`）；
/// - 核心库自带纯 Swift 的 ``SwiftFeedParser``，在 Windows/Linux 或 `XMLParser` 失败时兜底；
/// - 两者输出结构完全一致，排序层不感知具体实现。
public protocol FeedParsing: Sendable {
    func parse(data: Data, source: FeedSource) throws -> ParsedFeed
}

public enum FeedParseError: Error, Equatable, Sendable {
    case invalidEncoding
    case notAFeed
}
