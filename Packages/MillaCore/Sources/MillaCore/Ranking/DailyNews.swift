import Foundation

/// 每日新闻支持：时段计算、候选挑选、一句话概括。
///
/// 纯函数、跨平台可测；App 层的 `DailyNewsViewModel` 只负责
/// 网络同步、持久化与展示编排。
public enum DailyNews {

    /// 当前时段；0:00–7:00 返回 nil（该时段没有自己的新闻批次）。
    /// - 上午版：7:00–12:00；午后版：12:00–24:00。
    public static func currentSlot(
        now: Date,
        calendar: Calendar = .current
    ) -> (key: String, name: String)? {
        let hour = calendar.component(.hour, from: now)
        var formatter: DateFormatter {
            let formatter = DateFormatter()
            formatter.calendar = calendar
            // DateFormatter 的时区独立于 calendar，必须显式同步，
            // 否则 UTC 日历下日期串会落到本地时区的另一天
            formatter.timeZone = calendar.timeZone
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "yyyy-MM-dd"
            return formatter
        }
        let day = formatter.string(from: now)
        switch hour {
        case 7..<12: return ("\(day)-am", "上午版")
        case 12..<24: return ("\(day)-pm", "午后版")
        default: return nil
        }
    }

    /// 从候选中挑选每日新闻 Top N：
    /// - 只保留启用源中 `windowHours` 小时内发布的文章；
    /// - 深度侧重的源不参与（长文/话题讨论不追求时效）；
    /// - 打分与信息流一致（按源侧重调整权重与半衰期），分数并列时新者优先。
    public static func topItems(
        sources: [FeedSource],
        items: [FeedItem],
        config: RankingConfiguration = .default,
        now: Date,
        windowHours: Double = 24,
        limit: Int = 10
    ) -> [RankedFeedItem] {
        let weights = config.normalizedWeights
        let cutoff = now.addingTimeInterval(-windowHours * 3_600)
        let sourcesByID = Dictionary(
            uniqueKeysWithValues: sources.filter(\.isEnabled).map { ($0.id, $0) }
        )

        return items.compactMap { item -> RankedFeedItem? in
            guard let source = sourcesByID[item.sourceID], source.focus != .depth else {
                return nil
            }
            guard let publishedAt = item.publishedAt,
                  publishedAt >= cutoff, publishedAt <= now else {
                return nil
            }
            let sourceWeights = FeedRankingService.effectiveWeights(
                global: weights, focus: source.focus
            )
            let halfLife = FeedRankingService.effectiveHalfLife(
                global: config.recencyHalfLifeHours, focus: source.focus
            )
            let recency = FeedRankingService.recencyScore(
                publishedAt: publishedAt, now: now, halfLifeHours: halfLife
            )
            let score = sourceWeights.quality * source.qualityScore
                + sourceWeights.recency * recency
            return RankedFeedItem(
                item: item,
                sourceID: item.sourceID,
                qualityScore: source.qualityScore,
                recencyScore: recency,
                score: score
            )
        }
        .sorted { lhs, rhs in
            if lhs.score != rhs.score { return lhs.score > rhs.score }
            return (lhs.item.publishedAt ?? .distantPast) > (rhs.item.publishedAt ?? .distantPast)
        }
        .prefix(limit)
        .map { $0 }
    }

    /// 一句话概括：取摘要第一句，过短则补第二句，再按字数截断；
    /// 摘要为空时回退到标题。
    public static func makeHeadline(
        title: String,
        summary: String,
        limit: Int = 56
    ) -> String {
        let cleaned = summary
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let source = cleaned.isEmpty ? title : cleaned
        let terminators = CharacterSet(charactersIn: "。！？!?.;；")
        let sentences = source
            .components(separatedBy: terminators)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        guard var headline = sentences.first else { return title }
        // 第一句太短（如"快讯"）时补第二句；16 字以上本身已是合格的概括
        if headline.count < 16, sentences.count > 1 {
            headline += "，" + sentences[1]
        }
        if headline.count > limit {
            headline = String(headline.prefix(limit)) + "…"
        }
        return headline
    }
}
