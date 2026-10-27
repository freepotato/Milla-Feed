import Foundation
import Observation
import MillaCore

/// 每日新闻：数据源为热摸爽主页热榜（综合 + 各大类）。
///
/// 时段规则（产品要求）：每小时抓取一次；本小时内已抓过则直接展示缓存，
/// 跨小时进入页面才重新抓取。
///
/// 一次请求返回全部来源榜单，切分类只看缓存不重新请求；
/// 时段计算与榜单组装在 MillaCore（跨平台可测）。
@MainActor
@Observable
final class DailyNewsViewModel {

    /// 顶部分类芯片（"综合" + 各大类）。
    struct Category: Identifiable, Equatable {
        let key: String
        let label: String
        var id: String { key }
    }

    /// 默认分类："综合"。
    static let combinedKey = "combined"

    private(set) var categories: [Category] = []
    private(set) var events: [RemoShuangHot.Entry] = []
    private(set) var slotName = ""
    private(set) var fetchedAt: Date?
    private(set) var emptyMessage: String?
    var selectedCategoryKey = DailyNewsViewModel.combinedKey
    var isGenerating = false

    private var entriesByCategory: [String: [RemoShuangHot.Entry]] = [:]
    private let service: RemoShuangNewsService

    init(service: RemoShuangNewsService = RemoShuangNewsService()) {
        self.service = service
    }

    // MARK: - 加载

    /// 进入页面时调用：本小时已抓过直接展示，否则抓取。
    func loadIfNeeded() async {
        emptyMessage = nil
        let now = Date()
        let slot = DailyNews.hourlySlot(now: now)

        if let stored = storedDigest(), stored.slotKey == slot.key {
            present(stored)
            return
        }

        await generate(slot: slot, now: now)
    }

    // MARK: - 分类切换

    func selectCategory(_ key: String) {
        selectedCategoryKey = key
        applySelection()
    }

    /// 按分类键取对应条目（TabView 分页直接使用，不依赖当前选中状态）。
    func events(for categoryKey: String) -> [RemoShuangHot.Entry] {
        entriesByCategory[categoryKey] ?? []
    }

    // MARK: - 抓取

    private func generate(slot: (key: String, name: String), now: Date) async {
        isGenerating = true
        defer { isGenerating = false }
        do {
            let sources = try await service.fetchHot()
            let labels = RemoShuangHot.categoryLabels(of: sources)
            var entries: [String: [RemoShuangHot.Entry]] = [
                Self.combinedKey: RemoShuangHot.entries(from: sources, categoryLabel: nil)
            ]
            for label in labels {
                entries[label] = RemoShuangHot.entries(from: sources, categoryLabel: label)
            }
            let digest = DailyNewsDigest(
                slotKey: slot.key,
                slotName: slot.name,
                fetchedAt: now,
                labels: labels,
                entries: entries
            )
            saveDigest(digest)
            present(digest)
            if events.isEmpty {
                emptyMessage = "本小时热榜暂时没有内容，下个时段再来看看。"
            }
        } catch {
            // 抓取失败：有旧缓存就继续展示，否则提示
            if let stored = storedDigest() {
                present(stored)
            } else {
                emptyMessage = "抓取失败，请检查网络后稍后再试。"
            }
        }
    }

    // MARK: - 展示

    private func present(_ digest: DailyNewsDigest) {
        slotName = digest.slotName
        fetchedAt = digest.fetchedAt
        entriesByCategory = digest.entries
        categories = [Category(key: Self.combinedKey, label: "综合")]
            + digest.labels.map { Category(key: $0, label: $0) }
        // 当前选中的分类在新数据里不存在时回到默认
        if !categories.contains(where: { $0.key == selectedCategoryKey }) {
            selectedCategoryKey = Self.combinedKey
        }
        applySelection()
    }

    func applySelection() {
        events = entriesByCategory[selectedCategoryKey] ?? []
    }

    // MARK: - 持久化

    /// 只保存最近一份；slotKey 用于判断"本小时是否已抓取过"。
    private struct DailyNewsDigest: Codable {
        var slotKey: String
        var slotName: String
        var fetchedAt: Date
        var labels: [String]
        var entries: [String: [RemoShuangHot.Entry]]
    }

    private static let defaultsKey = "dailyNews.hotLatest.v1"

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
}
