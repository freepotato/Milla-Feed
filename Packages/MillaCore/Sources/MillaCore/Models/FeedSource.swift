import Foundation

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
        sampleSize: Int = 5,
        qualityScore: Double = 0.8,
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
        self.addedAt = addedAt
        self.lastFetchedAt = lastFetchedAt
    }

    /// 实际生效的抽样数。
    public var effectiveSampleSize: Int {
        sampleSize > 0 ? sampleSize : dailyLimit
    }
}
