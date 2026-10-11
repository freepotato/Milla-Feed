import Foundation

/// 一条 Feed 内容（文章）。
///
/// `id` 不是随机值，而是由 `订阅源 + guid/link/title` 推导出的稳定哈希，
/// 这样同一篇文章在多次拉取、甚至多台设备重建数据库后，仍然能被去重池识别。
public struct FeedItem: Identifiable, Codable, Equatable, Hashable, Sendable {

    /// 稳定内容标识（见 ``StableIdentifier``）。
    public var id: String

    /// 所属订阅源。
    public var sourceID: UUID

    /// 标题。
    public var title: String

    /// 原文链接。
    public var link: URL?

    /// 纯文本摘要（已去除 HTML 标签）。
    public var summary: String

    /// 正文 HTML（content:encoded / Atom content），可能为空。
    public var contentHTML: String

    /// 封面图地址。
    public var imageURL: URL?

    /// 作者。
    public var author: String?

    /// 发布时间。
    public var publishedAt: Date?

    public init(
        id: String,
        sourceID: UUID,
        title: String,
        link: URL?,
        summary: String,
        contentHTML: String,
        imageURL: URL?,
        author: String?,
        publishedAt: Date?
    ) {
        self.id = id
        self.sourceID = sourceID
        self.title = title
        self.link = link
        self.summary = summary
        self.contentHTML = contentHTML
        self.imageURL = imageURL
        self.author = author
        self.publishedAt = publishedAt
    }
}
