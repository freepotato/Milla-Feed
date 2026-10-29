import Foundation
import Observation
import MillaCore

/// 每日新闻：数据源为热摸爽首页榜单与「正在升温」。
///
/// 刷新规则（产品要求）：每次打开页面都在后台抓取一次，先展示本地缓存保证
/// 可立即浏览，抓取完成后只在内容有变化时带动画替换；切分类只看缓存。
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
    private(set) var fetchedAt: Date?
    private(set) var emptyMessage: String?
    private(set) var rising: [RemoShuangRanked.Rising] = []
    /// 每次后台数据真正变化时 +1，视图据此决定是否播放替换动画。
    private(set) var dataVersion = 0
    var selectedCategoryKey = DailyNewsViewModel.combinedKey
    var isRefreshing = false

    private var entriesByCategory: [String: [RemoShuangRanked.Entry]] = [:]
    private let service: RemoShuangNewsService

    init(service: RemoShuangNewsService = RemoShuangNewsService()) {
        self.service = service
    }

    // MARK: - 加载

    /// 进入页面时调用：先恢复上次缓存，再在后台刷新。
    func load() async {
        presentStored()
        await refresh()
    }

    /// 每次打开页面都抓一次；并发触发时只保留一次请求。
    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        emptyMessage = nil

        async let rankedTask = service.fetchRanked()
        async let risingTask = service.fetchRising()

        do {
            let items = try await rankedTask
            let risingItems = (try? await risingTask) ?? rising
            apply(items: items, rising: risingItems, fetchedAt: Date(), persist: true)
        } catch {
            // 有缓存就继续展示旧内容，只在完全空页时提示失败
            if categories.isEmpty, let stored = storedDigest() {
                present(stored)
            } else if categories.isEmpty {
                emptyMessage = "抓取失败，请检查网络后重试。"
            }
        }
    }

    // MARK: - 分类切换

    func selectCategory(_ key: String) {
        selectedCategoryKey = key
    }

    /// 按分类键取对应条目（TabView 分页直接使用，不依赖当前选中状态）。
    func events(for categoryKey: String) -> [RemoShuangRanked.Entry] {
        entriesByCategory[categoryKey] ?? []
    }

    // MARK: - 应用数据

    private func apply(
        items: [RemoShuangRanked.Item],
        rising newRising: [RemoShuangRanked.Rising],
        fetchedAt: Date,
        persist: Bool
    ) {
        let labels = RemoShuangRanked.categoryLabels(for: items)
        var entries: [String: [RemoShuangRanked.Entry]] = [
            Self.combinedKey: RemoShuangRanked.entries(from: items, category: nil)
        ]
        for label in labels {
            entries[label] = RemoShuangRanked.entries(from: items, category: label)
        }

        let changed = entries != entriesByCategory || newRising != rising
        entriesByCategory = entries
        rising = newRising
        categories = [Category(key: Self.combinedKey, label: "综合")]
            + labels.map { Category(key: $0, label: $0) }
        self.fetchedAt = fetchedAt
        // 当前选中的分类在新数据里不存在时回到综合
        if !categories.contains(where: { $0.key == selectedCategoryKey }) {
            selectedCategoryKey = Self.combinedKey
        }
        if changed {
            dataVersion += 1
        }
        if persist {
            saveDigest()
        }
        if entries[Self.combinedKey]?.isEmpty != false {
            emptyMessage = "热榜暂时没有内容，稍后再试试。"
        }
    }

    // MARK: - 持久化

    private struct Digest: Codable {
        var fetchedAt: Date
        var labels: [String]
        var entries: [String: [RemoShuangRanked.Entry]]
        var rising: [RemoShuangRanked.Rising]
    }

    private static let defaultsKey = "dailyNews.rankedLatest.v2"

    private func presentStored() {
        guard categories.isEmpty, let digest = storedDigest() else { return }
        present(digest)
    }

    private func present(_ digest: Digest) {
        entriesByCategory = digest.entries
        rising = digest.rising
        fetchedAt = digest.fetchedAt
        categories = [Category(key: Self.combinedKey, label: "综合")]
            + digest.labels.map { Category(key: $0, label: $0) }
        if !categories.contains(where: { $0.key == selectedCategoryKey }) {
            selectedCategoryKey = Self.combinedKey
        }
    }

    private func storedDigest() -> Digest? {
        guard let data = UserDefaults.standard.data(forKey: Self.defaultsKey) else {
            return nil
        }
        return try? JSONDecoder().decode(Digest.self, from: data)
    }

    private func saveDigest() {
        let digest = Digest(
            fetchedAt: fetchedAt ?? Date(),
            labels: categories.dropFirst().map(\.label),
            entries: entriesByCategory,
            rising: rising
        )
        if let data = try? JSONEncoder().encode(digest) {
            UserDefaults.standard.set(data, forKey: Self.defaultsKey)
        }
    }
}
