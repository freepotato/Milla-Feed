import Foundation
import Observation
import MillaCore

/// 首页信息流状态。
///
/// 排序过程完全使用 MillaCore 的纯逻辑：
/// 本类只负责“拉网络 -> 取本地快照 -> 调排序 -> 回写去重池”的编排。
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
    private(set) var sourceTitles: [UUID: String] = [:]
    private(set) var readIDs: Set<String> = []
    private(set) var failureMessage: String?

    var isRefreshing = false

    private let syncService: FeedSyncService

    init(syncService: FeedSyncService = FeedSyncService()) {
        self.syncService = syncService
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

    /// 仅根据本地数据重建列表（从详情页返回时刷新已读态使用，不发起网络请求）。
    func rebuild(repository: FeedRepository, settings: AppSettings) {
        let data = repository.loadHomeData()

        sourceTitles = Dictionary(
            uniqueKeysWithValues: data.coreSources.map { ($0.id, $0.title) }
        )
        readIDs = data.readIDs

        guard !data.coreSources.isEmpty else {
            rankedItems = []
            state = .empty(message: "还没有订阅源，点击右上角设置添加。")
            return
        }

        let configuration = settings.makeRankingConfiguration()

        // 第一轮：去重池生效
        let outcome = FeedRankingService.rank(
            sources: data.coreSources,
            items: data.items,
            shownIdentifiers: data.shownIDs,
            config: configuration
        )

        var ranked = outcome.ranked

        // 兜底：全部内容都展示过（例如没有新内容时再次下拉），
        // 则临时忽略去重池，避免信息流空白；新内容到来后旧内容仍会自动退场。
        if ranked.isEmpty, !data.items.isEmpty {
            ranked = FeedRankingService.rank(
                sources: data.coreSources,
                items: data.items,
                shownIdentifiers: [],
                config: configuration
            ).ranked
        }

        rankedItems = ranked

        if ranked.isEmpty {
            state = .empty(message: "暂时拉取不到内容，下拉重试，或检查订阅源设置。")
        } else {
            state = .loaded
            // 已展示内容进入去重池
            repository.markShown(identifiers: Set(ranked.map(\.id)))
        }
    }
}
