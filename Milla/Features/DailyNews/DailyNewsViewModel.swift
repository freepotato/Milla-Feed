import Foundation
import Observation
import MillaCore

/// 每日新闻：每天两个时段各从全部订阅源抓取一次，挑出 24 小时内
/// 最具时效性的 10 条文章，各配一句话概括。
///
/// 时段规则（产品要求）：
/// - 上午版：7:00–12:00 进入页面时生成一次；当天已生成则直接展示，不重新抓取；
/// - 午后版：12:00 之后同理；
/// - 0:00–7:00 没有自己的时段，展示最近一次生成的版本。
///
/// 候选范围与挑选逻辑在 MillaCore 的 ``DailyNews`` 中（跨平台可测），
/// 本类只做网络同步、持久化与展示编排。
@MainActor
@Observable
final class DailyNewsViewModel {

    /// 列表条目。
    struct Entry: Identifiable {
        /// 文章稳定标识。
        let id: String
        /// 一句话概括。
        let headline: String
        let sourceTitle: String
        let publishedAt: Date?
        /// 原文（用于跳转详情页）。
        let item: FeedItem
    }

    private(set) var entries: [Entry] = []
    private(set) var slotName = ""
    private(set) var generatedAt: Date?
    private(set) var emptyMessage: String?
    var isGenerating = false

    private let syncService: FeedSyncService

    init(syncService: FeedSyncService = FeedSyncService()) {
        self.syncService = syncService
    }

    // MARK: - 加载

    /// 进入页面时调用：当天该时段已抓过直接展示，否则抓取并生成。
    func loadIfNeeded(repository: FeedRepository, settings: AppSettings) async {
        emptyMessage = nil
        let now = Date()

        guard let slot = DailyNews.currentSlot(now: now) else {
            // 凌晨时段：展示最近一次生成的版本
            if let stored = storedDigest() {
                present(stored, repository: repository)
            } else if entries.isEmpty {
                emptyMessage = "每日新闻会在早上 7 点后生成第一批，稍后再来看看。"
            }
            return
        }

        if let stored = storedDigest(), stored.slotKey == slot.key {
            present(stored, repository: repository)
            return
        }

        await generate(slot: slot, repository: repository, settings: settings, now: now)
    }

    // MARK: - 生成

    private func generate(
        slot: (key: String, name: String),
        repository: FeedRepository,
        settings: AppSettings,
        now: Date
    ) async {
        isGenerating = true
        // 先拉一轮最新内容；失败不阻塞——仍用本地已有数据生成
        _ = await syncService.sync(
            sources: repository.allStoredSources(),
            repository: repository
        )

        let top = DailyNews.topItems(
            sources: repository.coreSources(enabledOnly: true),
            items: repository.recentCoreItems(limit: 300),
            config: settings.makeRankingConfiguration(),
            now: now
        )

        let digest = DailyNewsDigest(
            slotKey: slot.key,
            slotName: slot.name,
            generatedAt: now,
            entries: top.map { ranked in
                DailyNewsDigest.StoredEntry(
                    articleID: ranked.item.id,
                    headline: DailyNews.makeHeadline(
                        title: ranked.item.title,
                        summary: ranked.item.summary
                    )
                )
            }
        )
        saveDigest(digest)
        isGenerating = false

        if digest.entries.isEmpty {
            entries = []
            generatedAt = digest.generatedAt
            slotName = slot.name
            emptyMessage = "过去 24 小时没有可入选的时效性文章，下个时段再来看看。"
        } else {
            present(digest, repository: repository)
        }
    }

    // MARK: - 持久化

    /// 只保存最近一份；slotKey 用于判断"当天该时段是否已抓取过"。
    private struct DailyNewsDigest: Codable {
        struct StoredEntry: Codable {
            var articleID: String
            var headline: String
        }
        var slotKey: String
        var slotName: String
        var generatedAt: Date
        var entries: [StoredEntry]
    }

    private static let defaultsKey = "dailyNews.latest.v1"

    private func storedDigest() -> DailyNewsDigest? {
        guard let data = UserDefaults.standard.data(forKey: Self.defaultsKey) else {
            return nil
        }
        return try? JSONDecoder().decode(DailyNewsDigest.self, from: data)
    }

    private func saveDigest(_ digest: DailyNewsDigest) {
        if let data = try? JSONEncoder().encode(digest) {
            UserDefaults.standard.set(data, forKey: Self.defaultsKey)
        }
    }

    /// 按持久化的条目顺序，从本地库取回原文并物化展示列表；
    /// 文章已被删除（如订阅源移除）时跳过该条。
    private func present(_ digest: DailyNewsDigest, repository: FeedRepository) {
        var materialized: [Entry] = []
        materialized.reserveCapacity(digest.entries.count)
        let sourceTitles = Dictionary(
            uniqueKeysWithValues: repository.coreSources().map { ($0.id, $0.title) }
        )
        for stored in digest.entries {
            guard let article = repository.fetchArticle(identifier: stored.articleID) else {
                continue
            }
            let item = article.makeCoreItem()
            materialized.append(
                Entry(
                    id: stored.articleID,
                    headline: stored.headline,
                    sourceTitle: sourceTitles[item.sourceID] ?? "未知来源",
                    publishedAt: item.publishedAt,
                    item: item
                )
            )
        }
        entries = materialized
        slotName = digest.slotName
        generatedAt = digest.generatedAt
        if materialized.isEmpty {
            emptyMessage = "本时段的新闻已失效，下个时段再来看看。"
        }
    }
}
