import Foundation
import Observation
import MillaCore

/// 首页信息流状态。
///
/// 顺序规则（产品要求）：
/// - 文章只增不换：下拉刷新不会重排或移除旧文章，已读文章同样保留；
/// - 质量权重 / 时效权重 / 抽样只作用于"本次新增的文章批次"，
///   新批次按排序结果整体插到列表最前，旧文章顺序永久保持；
/// - 信息流只展示最前面的 `timelineLimit` 条，其余仅归档不再展示；
/// - 顺序通过 FeedRepository 持久化，App 重启后保持。
///
/// 排序算法本身完全使用 MillaCore 的纯逻辑，本类只做
/// "拉网络 -> 取本地快照 -> 对新增批次排序 -> 回写顺序"的编排。
@MainActor
@Observable
final class HomeViewModel {

    enum LoadState: Equatable {
        case initial
        case loading
        case loaded
        case empty(message: String)
        case error(message: String)

        static func == (lhs: LoadState, rhs: LoadState) -> Bool {
            switch (lhs, rhs) {
            case (.initial, .initial), (.loading, .loading), (.loaded, .loaded):
                return true
            case (.empty(let a), .empty(let b)), (.error(let a), .error(let b)):
                return a == b
            default:
                return false
            }
        }
    }

    private(set) var state: LoadState = .initial
    private(set) var rankedItems: [RankedFeedItem] = []

    /// 信息流只展示排序最前的若干条，其余继续留在本地，作为历史文章归档。
    static let timelineLimit = 30

    var visibleItems: [RankedFeedItem] {
        Array(rankedItems.prefix(Self.timelineLimit))
    }

    private(set) var sourceTitles: [UUID: String] = [:]
    private(set) var readIDs: Set<String> = []
    private(set) var failureMessage: String?

    var isRefreshing = false

    private let syncService: FeedSyncService

    init(syncService: FeedSyncService = FeedSyncService()) {
        self.syncService = syncService
    }

    // MARK: - 搜索

    /// 本地检索（标题/摘要/作者，不区分大小写），结果按发布时间倒序。
    /// 不影响时间线本身，仅用于横幅搜索框的结果展示。
    func search(_ query: String, repository: FeedRepository) -> [RankedFeedItem] {
        repository.searchItems(query: query).map {
            RankedFeedItem(item: $0, sourceID: $0.sourceID, qualityScore: 0, recencyScore: 0, score: 0)
        }
    }

    // MARK: - 加载

    func load(
        repository: FeedRepository,
        settings: AppSettings,
        refreshNetwork: Bool
    ) async {
        if rankedItems.isEmpty {
            state = .loading
        }

        if refreshNetwork {
            isRefreshing = true
            let storedSources = repository.allStoredSources()
            let report = await syncService.sync(
                sources: storedSources,
                repository: repository
            )
            isRefreshing = false
            failureMessage = report.failures.isEmpty
                ? nil
                : "\(report.failures.count) 个订阅源更新失败：" +
                  report.failures.map(\.title).joined(separator: "、")
        }

        rebuild(repository: repository, settings: settings)
    }

    /// 仅根据本地数据重建列表（从详情页返回刷新已读态时使用，不发起网络请求，
    /// 也不改变既有顺序）。
    func rebuild(repository: FeedRepository, settings: AppSettings) {
        let data = repository.loadHomeData()

        sourceTitles = Dictionary(
            uniqueKeysWithValues: data.coreSources.map { ($0.id, $0.title) }
        )
        readIDs = data.readIDs

        guard !data.coreSources.isEmpty else {
            state = .empty(message: "还没有订阅源，点击右上角设置添加。")
            return
        }

        let configuration = settings.makeRankingConfiguration()
        let itemsByID = Dictionary(
            uniqueKeysWithValues: data.items.map { ($0.id, $0) }
        )

        var order = repository.loadOrderedIdentifiers()
        var seen = repository.loadSeenIdentifiers()

        if order.isEmpty && seen.isEmpty {
            // 首批（首次安装 / 旧版本升级后第一次启动）：
            // 当前全部本地内容作为一个批次参与一次排序与抽样，之后顺序固定，
            // 未抽中的文章进入"已见池"，不会在以后冒充新内容。
            if data.items.isEmpty {
                rankedItems = []
                state = .empty(message: "暂时拉取不到内容，下拉重试，或检查订阅源设置。")
                return
            }
            let firstBatch = FeedRankingService.rank(
                sources: data.coreSources,
                items: data.items,
                shownIdentifiers: [],
                config: configuration
            ).ranked
            order = firstBatch.map(\.id)
        } else {
            // 增量批次：只有"已见池之外"的文章（即本次新抓取到的）参与排序/抽样
            let newItems = data.items.filter { !seen.contains($0.id) }
            if !newItems.isEmpty {
                let rankedNew = FeedRankingService.rank(
                    sources: data.coreSources,
                    items: newItems,
                    shownIdentifiers: [],
                    config: configuration
                ).ranked
                // 新批次整体置顶，旧顺序原样拼接
                order = rankedNew.map(\.id) + order
            }
        }

        // 当前库中的全部文章记入已见池（含首批抽样未中的）
        seen.formUnion(data.items.map(\.id))
        repository.saveSeenIdentifiers(seen)

        // 按持久化顺序物化；本地已不存在的条目（如订阅源被删除）从顺序表清理
        var materialized: [RankedFeedItem] = []
        materialized.reserveCapacity(order.count)
        var survivingIDs: [String] = []
        survivingIDs.reserveCapacity(order.count)
        for id in order {
            if let item = itemsByID[id] {
                survivingIDs.append(id)
                materialized.append(
                    RankedFeedItem(
                        item: item,
                        sourceID: item.sourceID,
                        qualityScore: 0,
                        recencyScore: 0,
                        score: 0
                    )
                )
            }
        }
        if survivingIDs != order {
            order = survivingIDs
        }
        repository.saveOrderedIdentifiers(order)

        rankedItems = materialized
        state = materialized.isEmpty
            ? .empty(message: "暂时拉取不到内容，下拉重试，或检查订阅源设置。")
            : .loaded
    }
}
