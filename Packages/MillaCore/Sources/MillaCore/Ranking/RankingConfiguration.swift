import Foundation

/// 信息流排序配置。可在 App 设置页调整，通过 UserDefaults / JSON 持久化。
public struct RankingConfiguration: Codable, Equatable, Sendable {

    /// 质量权重 qualityWeight，默认 0.6。
    public var qualityWeight: Double

    /// 新鲜度权重 recencyWeight，默认 0.4。
    public var recencyWeight: Double

    /// 新鲜度半衰期（小时）。文章年龄达到该值时 recencyScore = 0.5。
    public var recencyHalfLifeHours: Double

    /// 缺少发布时间时使用的新鲜度兜底分（0...1）。
    public var missingDateRecency: Double

    /// 是否启用随机加权抽样。`false`（默认）时为确定性 Top-K，结果稳定可回归。
    public var stochasticSampling: Bool

    /// 随机抽样种子。传入固定值时抽样结果可复现（用于测试）；`nil` 表示随机。
    public var randomSeed: UInt64?

    public init(
        qualityWeight: Double = 0.6,
        recencyWeight: Double = 0.4,
        recencyHalfLifeHours: Double = 24,
        missingDateRecency: Double = 0.25,
        stochasticSampling: Bool = false,
        randomSeed: UInt64? = nil
    ) {
        self.qualityWeight = qualityWeight
        self.recencyWeight = recencyWeight
        self.recencyHalfLifeHours = max(1, recencyHalfLifeHours)
        self.missingDateRecency = min(max(missingDateRecency, 0), 1)
        self.stochasticSampling = stochasticSampling
        self.randomSeed = randomSeed
    }

    public static let `default` = RankingConfiguration()

    /// 归一化后的权重（两者之和恒为 1；全为 0 时退化为 0.5/0.5）。
    public var normalizedWeights: (quality: Double, recency: Double) {
        let total = qualityWeight + recencyWeight
        guard total > 0 else { return (0.5, 0.5) }
        return (qualityWeight / total, recencyWeight / total)
    }
}
