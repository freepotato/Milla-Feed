import Foundation

/// 排序后的单条结果（包含打分明细，便于调试与测试）。
public struct RankedFeedItem: Identifiable, Codable, Hashable, Sendable {
    public let item: FeedItem
    public let sourceID: UUID
    public let qualityScore: Double
    public let recencyScore: Double
    public let score: Double

    public var id: String { item.id }

    public init(
        item: FeedItem,
        sourceID: UUID,
        qualityScore: Double,
        recencyScore: Double,
        score: Double
    ) {
        self.item = item
        self.sourceID = sourceID
        self.qualityScore = qualityScore
        self.recencyScore = recencyScore
        self.score = score
    }
}

/// 一次排序的完整输出。
public struct RankingOutcome: Sendable, Equatable {
    /// 最终用于展示的有序结果。
    public let ranked: [RankedFeedItem]
    /// 因已进入去重池而被排除的内容 ID。
    public let excludedAsShown: [String]

    public init(ranked: [RankedFeedItem], excludedAsShown: [String]) {
        self.ranked = ranked
        self.excludedAsShown = excludedAsShown
    }
}

/// 多订阅源交替排序算法。
///
/// 纯函数、无副作用、无平台依赖：
/// 1. 只保留启用订阅源的内容，移除去重池中的条目；
/// 2. 每个订阅源先取“当日”条目（无当日内容时回退到最新内容，保证低频源不消失）；
/// 3. 按 `dailyLimit` 截断候选；
/// 4. 按 `score = wq * qualityScore + wr * recencyScore` 抽样 `sampleSize` 条
///    （默认确定性 Top-K，可切换加权随机抽样）；
/// 5. 贪心交替合并：每轮选择剩余分数最高、且与上一条不同源的条目，
///    从而在尊重综合得分的前提下避免单一订阅源霸屏。
public enum FeedRankingService {

    /// 新鲜度指数衰减：age=0 时为 1，age=halfLife 时为 0.5。
    public static func recencyScore(
        publishedAt: Date?,
        now: Date = Date(),
        halfLifeHours: Double = 24,
        missingFallback: Double = 0.25
    ) -> Double {
        guard let publishedAt else { return missingFallback }
        let ageHours = max(0, now.timeIntervalSince(publishedAt) / 3_600)
        return pow(0.5, ageHours / max(1, halfLifeHours))
    }

    public static func rank(
        sources: [FeedSource],
        items: [FeedItem],
        shownIdentifiers: Set<String> = [],
        config: RankingConfiguration = .default,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> RankingOutcome {
        let weights = config.normalizedWeights

        // 1. 启用源索引
        let enabledSources = sources.filter(\.isEnabled)
        let sourceMap = Dictionary(uniqueKeysWithValues: enabledSources.map { ($0.id, $0) })

        // 2. 去重池过滤
        var excludedAsShown: [String] = []
        let liveItems = items.filter { item in
            guard sourceMap[item.sourceID] != nil else { return false }
            if shownIdentifiers.contains(item.id) {
                excludedAsShown.append(item.id)
                return false
            }
            return true
        }

        // 3. 逐源：日限 -> 打分 -> 抽样
        var queues: [(sourceIndex: Int, queue: [RankedFeedItem])] = []

        for (sourceIndex, source) in enabledSources.enumerated() {
            let sourceItems = liveItems.filter { $0.sourceID == source.id }

            let candidates = dailyCandidates(
                from: sourceItems,
                dailyLimit: source.dailyLimit,
                now: now,
                calendar: calendar
            )

            // 按订阅源侧重调整有效权重与半衰期：
            // 时效源——新鲜度权重 ×2（半衰期不变：源内 quality 恒定，
            //   缩短半衰期只会反向压低新文章的 recency，产生悖论）；
            // 深度源——质量权重 ×2、半衰期 ×4，旧长文保持竞争力。
            let sourceWeights = effectiveWeights(global: weights, focus: source.focus)
            let sourceHalfLife = effectiveHalfLife(
                global: config.recencyHalfLifeHours,
                focus: source.focus
            )

            let scored: [RankedFeedItem] = candidates.map { item in
                let recency = recencyScore(
                    publishedAt: item.publishedAt,
                    now: now,
                    halfLifeHours: sourceHalfLife,
                    missingFallback: config.missingDateRecency
                )
                let score = sourceWeights.quality * source.qualityScore
                    + sourceWeights.recency * recency
                return RankedFeedItem(
                    item: item,
                    sourceID: source.id,
                    qualityScore: source.qualityScore,
                    recencyScore: recency,
                    score: score
                )
            }

            let sampled = self.sample(
                from: scored,
                sampleSize: source.effectiveSampleSize,
                stochastic: config.stochasticSampling,
                seed: config.randomSeed
            )

            // 展示顺序：源内按综合分降序（抽样可能是随机的）
            let ordered = sampled.sorted { lhs, rhs in
                if lhs.score != rhs.score { return lhs.score > rhs.score }
                switch (lhs.item.publishedAt, rhs.item.publishedAt) {
                case let (l?, r?):
                    if l != r { return l > r }
                case (.some, .none): return true
                case (.none, .some): return false
                default: break
                }
                return lhs.item.id < rhs.item.id
            }

            if !ordered.isEmpty {
                queues.append((sourceIndex, ordered))
            }
        }

        // 4. 贪心交替合并
        let ranked = interleave(queues)
        return RankingOutcome(
            ranked: ranked,
            excludedAsShown: excludedAsShown.sorted()
        )
    }

    // MARK: - 侧重调整

    /// 按侧重调整有效权重：侧重方向权重 ×2 后再归一化。
    /// 例：全局 0.6/0.4 下，时效源变为 0.6/0.8 → 0.43/0.57。
    public static func effectiveWeights(
        global: (quality: Double, recency: Double),
        focus: SourceFocus
    ) -> (quality: Double, recency: Double) {
        let qualityMultiplier: Double = focus == .depth ? 2 : 1
        let recencyMultiplier: Double = focus == .timeliness ? 2 : 1
        let q = global.quality * qualityMultiplier
        let r = global.recency * recencyMultiplier
        let total = q + r
        guard total > 0 else { return (0.5, 0.5) }
        return (q / total, r / total)
    }

    /// 按侧重调整半衰期：深度 ×4 让旧长文续命；时效与均衡不变
    /// （见 rank 内注释，缩短半衰期对时效源是反效果）。下限 1 小时。
    public static func effectiveHalfLife(global: Double, focus: SourceFocus) -> Double {
        let multiplier: Double = focus == .depth ? 4 : 1
        return max(1, global * multiplier)
    }

    // MARK: - 当日候选 + dailyLimit

    static func dailyCandidates(
        from items: [FeedItem],
        dailyLimit: Int,
        now: Date,
        calendar: Calendar
    ) -> [FeedItem] {
        // 新 -> 旧；无时间者排最后
        let newestFirst = items.sorted {
            switch ($0.publishedAt, $1.publishedAt) {
            case let (l?, r?):
                if l != r { return l > r }
            case (.some, .none): return true
            case (.none, .some): return false
            default: break
            }
            return $0.id < $1.id
        }

        let todays = newestFirst.filter { item in
            guard let date = item.publishedAt else { return false }
            return calendar.isDate(date, inSameDayAs: now)
        }

        // 当日无内容时回退到最新条目，避免更新不频繁的源在信息流里彻底消失
        let pool = todays.isEmpty ? newestFirst : todays
        if dailyLimit <= 0 { return pool }
        return Array(pool.prefix(dailyLimit))
    }

    // MARK: - 抽样

    static func sample(
        from scored: [RankedFeedItem],
        sampleSize: Int,
        stochastic: Bool,
        seed: UInt64?
    ) -> [RankedFeedItem] {
        if sampleSize <= 0 || scored.count <= sampleSize { return scored }

        guard stochastic else {
            // 确定性 Top-K
            return Array(scored.sorted {
                if $0.score != $1.score { return $0.score > $1.score }
                return $0.item.id < $1.item.id
            }.prefix(sampleSize))
        }

        // Efraimidis–Spiliotidis 加权随机抽样：
        // key = u^(1/w)，取 key 最大的 k 个。种子固定时结果可复现。
        var rng = SplitMix64(seed: seed ?? SplitMix64.randomSeed())
        let weighted = scored.map { item -> (RankedFeedItem, Double) in
            let unit = max(rng.nextUnit(), 1e-12)
            let weight = max(item.score, 1e-4)
            return (item, pow(unit, 1.0 / weight))
        }
        return weighted
            .sorted { $0.1 > $1.1 }
            .prefix(sampleSize)
            .map { $0.0 }
    }

    // MARK: - 交替合并

    /// 每轮取“剩余条目里综合分最高、且与上一条不同订阅源”的条目；
    /// 若只剩同一来源，则直接按分数输出。
    static func interleave(
        _ queues: [(sourceIndex: Int, queue: [RankedFeedItem])]
    ) -> [RankedFeedItem] {
        var queues = queues
        var result: [RankedFeedItem] = []
        var lastSourceID: UUID?

        while queues.contains(where: { !$0.queue.isEmpty }) {
            var bestIndex: Int?
            for (index, entry) in queues.enumerated() where !entry.queue.isEmpty {
                if entry.queue.first?.sourceID == lastSourceID {
                    // 若还存在其他源的候选，则本轮跳过同源
                    let hasAlternative = queues.contains {
                        !$0.queue.isEmpty && $0.queue.first?.sourceID != lastSourceID
                    }
                    if hasAlternative { continue }
                }
                if bestIndex == nil {
                    bestIndex = index
                } else if let current = bestIndex,
                          entry.queue[0].score > queues[current].queue[0].score {
                    bestIndex = index
                } else if let current = bestIndex,
                          entry.queue[0].score == queues[current].queue[0].score,
                          entry.sourceIndex < queues[current].sourceIndex {
                    bestIndex = index
                }
            }

            guard let pick = bestIndex else { break }
            let ranked = queues[pick].queue.removeFirst()
            result.append(ranked)
            lastSourceID = ranked.sourceID
        }
        return result
    }
}

// MARK: - SplitMix64（可复现的轻量伪随机）

struct SplitMix64 {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed
    }

    static func randomSeed() -> UInt64 {
        UInt64(bitPattern: Int64(Int(Date().timeIntervalSinceReferenceDate * 1_000_000)))
            ^ UInt64(bitPattern: Int64(ObjectIdentifier(WeakAnchor.shared).hashValue))
    }

    mutating func next() -> UInt64 {
        state &+= 0x9e37_79b9_7f4a_7c15
        var z = state
        z = (z ^ (z >> 30)) &* 0xbf58_476d_1ce4_e5b9
        z = (z ^ (z >> 27)) &* 0x94d0_49bb_1331_11eb
        return z ^ (z >> 31)
    }

    /// 返回 [0, 1) 的双精度随机数。
    mutating func nextUnit() -> Double {
        Double(next() >> 11) / Double(1 << 53)
    }

    private final class WeakAnchor {
        static let shared = WeakAnchor()
    }
}
