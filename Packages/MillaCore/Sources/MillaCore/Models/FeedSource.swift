import Foundation

/// 订阅源的筛选侧重：决定排序时"新鲜度 vs 质量"的取舍。
public enum SourceFocus: String, Codable, CaseIterable, Sendable {
    /// 均衡：使用全局权重与半衰期。
    case balanced
    /// 时效优先：新闻快讯类（如时政、新品发布）。新鲜度权重翻倍——
    /// 新快讯排名更靠前，过气快讯因质量贡献占比下降而迅速让位。
    case timeliness
    /// 深度优先：长文/思考类。质量权重翻倍、半衰期 ×4，
    /// 好文章即使发布多日仍有竞争力。
    case depth

    /// 设置页展示名称。
    public var title: String {
        switch self {
        case .balanced: "均衡"
        case .timeliness: "时效优先"
        case .depth: "深度优先"
        }
    }

    /// 设置页说明文案。
    public var detail: String {
        switch self {
        case .balanced: "新鲜度与质量按全局权重综合排序。"
        case .timeliness: "新闻快讯类：新文章排名更靠前，过气快讯迅速让位。"
        case .depth: "长文思考类：更看重质量，好文章发布多日仍有竞争力。"
        }
    }
}

/// 一个 RSS 订阅源。
///
/// 该类型位于纯 Swift 的 ``MillaCore`` 中，iOS 端的 SwiftData 存储模型会与它互相映射，
/// 排序算法只依赖本类型，因此可以在 Windows/Linux 上直接对算法做单元测试。
public struct FeedSource: Identifiable, Codable, Equatable, Hashable, Sendable {

    /// 稳定唯一标识。
    public var id: UUID

    /// 订阅源展示名称（例如 "Apple Newsroom"）。
    public var title: String

    /// RSS / Atom 地址（必须为 https）。
    public var url: URL

    /// 是否启用（停用后不参与拉取与排序）。
    public var isEnabled: Bool

    /// 单个订阅源每日最大候选条数（dailyLimit）。`0` 表示不限制。
    public var dailyLimit: Int

    /// 每日从候选条目中抽样条数（sampleSize）。`0` 表示与 dailyLimit 相同。
    public var sampleSize: Int

    /// 订阅源质量分（qualityScore），范围 0...1。
    public var qualityScore: Double

    /// 筛选侧重（时效 / 深度 / 均衡），默认均衡。
    public var focus: SourceFocus

    /// 添加时间。
    public var addedAt: Date

    /// 最近一次成功拉取时间。
    public var lastFetchedAt: Date?

    public init(
        id: UUID = UUID(),
        title: String,
        url: URL,
        isEnabled: Bool = true,
        dailyLimit: Int = 10,
        sampleSize: Int = 2,
        qualityScore: Double = 0.8,
        focus: SourceFocus = .balanced,
        addedAt: Date = Date(),
        lastFetchedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.url = url
        self.isEnabled = isEnabled
        self.dailyLimit = max(0, dailyLimit)
        self.sampleSize = max(0, sampleSize)
        self.qualityScore = min(max(qualityScore, 0), 1)
        self.focus = focus
        self.addedAt = addedAt
        self.lastFetchedAt = lastFetchedAt
    }

    /// 向后兼容：旧版本持久化/JSON 中没有 focus 字段时按均衡处理。
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        url = try container.decode(URL.self, forKey: .url)
        isEnabled = try container.decode(Bool.self, forKey: .isEnabled)
        dailyLimit = try container.decode(Int.self, forKey: .dailyLimit)
        sampleSize = try container.decode(Int.self, forKey: .sampleSize)
        qualityScore = try container.decode(Double.self, forKey: .qualityScore)
        focus = try container.decodeIfPresent(SourceFocus.self, forKey: .focus) ?? .balanced
        addedAt = try container.decode(Date.self, forKey: .addedAt)
        lastFetchedAt = try container.decodeIfPresent(Date.self, forKey: .lastFetchedAt)
    }

    /// 实际生效的抽样数。
    public var effectiveSampleSize: Int {
        sampleSize > 0 ? sampleSize : dailyLimit
    }
}
