import Foundation
import Observation
import MillaCore

/// 每日新闻：数据源为热摸爽「今日大事」（Top 10 + 各分类板块）。
///
/// 时段规则（产品要求）：
/// - 上午版：7:00–12:00 进入页面时抓取一次；当天已抓过则直接展示缓存；
/// - 午后版：12:00 之后同理；
/// - 0:00–7:00 没有自己的时段，展示最近一次抓取的版本。
///
/// 一次请求返回全部分类，切分类只看缓存不重新请求；
/// 时段计算在 MillaCore 的 ``DailyNews`` 中（跨平台可测）。
@MainActor
@Observable
final class DailyNewsViewModel {

    /// 顶部分类芯片（"今日大事" + 接口返回的各板块）。
    struct Category: Identifiable, Equatable {
        let key: String
        let label: String
        var id: String { key }
    }

    /// 默认分类："今日大事"（Top 10）。
    static let topCategoryKey = "top"

    private(set) var categories: [Category] = []
    private(set) var events: [RemoShuangToday.Event] = []
    private(set) var slotName = ""
    private(set) var fetchedAt: Date?
    private(set) var emptyMessage: String?
    var selectedCategoryKey = DailyNewsViewModel.topCategoryKey
    var isGenerating = false

    private var payload: RemoShuangToday?
    private let service: RemoShuangNewsService

    init(service: RemoShuangNewsService = RemoShuangNewsService()) {
        self.service = service
    }

    // MARK: - 加载

    /// 进入页面时调用：当天该时段已抓过直接展示，否则抓取。
    func loadIfNeeded() async {
        emptyMessage = nil
        let now = Date()

        guard let slot = DailyNews.currentSlot(now: now) else {
            // 凌晨时段：展示最近一次抓取的版本
            if let stored = storedDigest() {
                present(stored)
            } else if events.isEmpty {
                emptyMessage = "每日新闻会在早上 7 点后更新第一批，稍后再来看看。"
            }
            return
        }

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

    // MARK: - 抓取

    private func generate(slot: (key: String, name: String), now: Date) async {
        isGenerating = true
        defer { isGenerating = false }
        do {
            let fetched = try await service.fetchToday()
            let digest = DailyNewsWebDigest(
                slotKey: slot.key,
                slotName: slot.name,
                fetchedAt: now,
                payload: fetched
            )
            saveDigest(digest)
            present(digest)
            if events.isEmpty {
                emptyMessage = "今日大事暂时没有内容，下个时段再来看看。"
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

    private func present(_ digest: DailyNewsWebDigest) {
        payload = digest.payload
        slotName = digest.slotName
        fetchedAt = digest.fetchedAt
        categories = [Category(key: Self.topCategoryKey, label: "今日大事")]
            + digest.payload.sections.map { Category(key: $0.key, label: $0.label) }
        // 当前选中的分类在新数据里不存在时回到默认
        if !categories.contains(where: { $0.key == selectedCategoryKey }) {
            selectedCategoryKey = Self.topCategoryKey
        }
        applySelection()
    }

    private func applySelection() {
        guard let payload else {
            events = []
            return
        }
        if selectedCategoryKey == Self.topCategoryKey {
            events = payload.top
        } else {
            events = payload.sections
                .first(where: { $0.key == selectedCategoryKey })?
                .items ?? []
        }
    }

    // MARK: - 持久化

    /// 只保存最近一份；slotKey 用于判断"当天该时段是否已抓取过"。
    private struct DailyNewsWebDigest: Codable {
        var slotKey: String
        var slotName: String
        var fetchedAt: Date
        var payload: RemoShuangToday
    }

    private static let defaultsKey = "dailyNews.webLatest.v1"

    private func storedDigest() -> DailyNewsWebDigest? {
        guard let data = UserDefaults.standard.data(forKey: Self.defaultsKey) else {
            return nil
        }
        return try? JSONDecoder().decode(DailyNewsWebDigest.self, from: data)
    }

    private func saveDigest(_ digest: DailyNewsWebDigest) {
        if let data = try? JSONEncoder().encode(digest) {
            UserDefaults.standard.set(data, forKey: Self.defaultsKey)
        }
    }
}
