import Foundation
import SwiftData
import MillaCore

/// SwiftData 仓储：所有持久化操作的唯一入口。
/// 排序算法不直接依赖本类，而是接收核心库的值类型，保证可跨平台测试。
@MainActor
@Observable
final class FeedRepository {

    let container: ModelContainer
    private let maxArticlesPerSource = 100

    init(container: ModelContainer) {
        self.container = container
    }

    convenience init(inMemory: Bool = false) throws {
        let schema = Schema([StoredFeedSource.self, StoredFeedArticle.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        try self.init(container: ModelContainer(for: schema, configurations: [configuration]))
    }

    private var context: ModelContext { container.mainContext }

    /// 显式保存挂起的改动（编辑订阅源参数后调用）。
    func persistPendingChanges() {
        try? context.save()
    }

    /// 首次启动预置订阅源（同步执行，保证首页第一次加载时数据已就绪）。
    func seedInitialSourcesIfNeeded(_ sources: [FeedSource]) {
        guard allStoredSources().isEmpty else { return }
        for source in sources {
            context.insert(StoredFeedSource(source))
        }
        try? context.save()
    }

    // MARK: - Sources

    func allStoredSources() -> [StoredFeedSource] {
        let descriptor = FetchDescriptor<StoredFeedSource>(
            sortBy: [SortDescriptor(\.addedAt, order: .forward)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    func coreSources(enabledOnly: Bool = false) -> [FeedSource] {
        allStoredSources()
            .filter { enabledOnly ? $0.isEnabled : true }
            .map { $0.makeCoreSource() }
    }

    @discardableResult
    func addSource(
        title: String,
        urlString: String,
        dailyLimit: Int,
        sampleSize: Int,
        qualityScore: Double
    ) throws -> StoredFeedSource {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedURL = urlString.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let url = URL(string: trimmedURL),
              let scheme = url.scheme?.lowercased(),
              scheme == "https" || scheme == "http" else {
            throw RepositoryError.invalidURL
        }

        let existing = allStoredSources()
        guard !existing.contains(where: { $0.urlString == trimmedURL }) else {
            throw RepositoryError.duplicateSource
        }

        let source = FeedSource(
            title: trimmedTitle.isEmpty ? url.host ?? "未命名订阅源" : trimmedTitle,
            url: url,
            dailyLimit: dailyLimit,
            sampleSize: sampleSize,
            qualityScore: qualityScore
        )
        let stored = StoredFeedSource(source)
        context.insert(stored)
        try context.save()
        return stored
    }

    func deleteSource(_ source: StoredFeedSource) {
        context.delete(source) // 级联删除文章
        try? context.save()
    }

    func markFetched(_ source: StoredFeedSource, at date: Date = Date()) {
        source.lastFetchedAt = date
        try? context.save()
    }

    // MARK: - Articles

    /// 批量写入拉取结果，返回新增条数。同一稳定标识不会重复插入。
    @discardableResult
    func upsertArticles(_ items: [FeedItem]) -> Int {
        guard !items.isEmpty else { return 0 }

        let sourceMap = Dictionary(
            allStoredSources().map { ($0.uuid, $0) },
            uniquingKeysWith: { first, _ in first }
        )

        let existingIDs = Set(
            allStoredSources()
                .flatMap { $0.articles }
                .map { $0.identifier }
        )

        var insertedCount = 0
        for item in items where !existingIDs.contains(item.id) {
            context.insert(StoredFeedArticle(item, source: sourceMap[item.sourceID]))
            insertedCount += 1
        }
        if insertedCount > 0 {
            try? context.save()
            pruneOldArticles()
        }
        return insertedCount
    }

    /// 最近的文章（用于排序输入），跨源按发布时间倒序，限量拉取。
    func recentCoreItems(limit: Int = 300) -> [FeedItem] {
        var descriptor = FetchDescriptor<StoredFeedArticle>(
            sortBy: [SortDescriptor(\.publishedAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        let articles = (try? context.fetch(descriptor)) ?? []
        return articles.map { $0.makeCoreItem() }
    }

    func shownIdentifiers() -> Set<String> {
        let descriptor = FetchDescriptor<StoredFeedArticle>(
            predicate: #Predicate<StoredFeedArticle> { $0.shown == true }
        )
        let articles = (try? context.fetch(descriptor)) ?? []
        return Set(articles.map { $0.identifier })
    }

    /// 首页排序所需的一次性数据快照。
    struct HomeData {
        let coreSources: [FeedSource]
        let items: [FeedItem]
        let shownIDs: Set<String>
        let readIDs: Set<String>
        let favoriteIDs: Set<String>
    }

    func loadHomeData(limit: Int = 300) -> HomeData {
        var descriptor = FetchDescriptor<StoredFeedArticle>(
            sortBy: [SortDescriptor(\.publishedAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        let articles = (try? context.fetch(descriptor)) ?? []
        return HomeData(
            coreSources: coreSources(enabledOnly: true),
            items: articles.map { $0.makeCoreItem() },
            shownIDs: Set(articles.filter(\.shown).map(\.identifier)),
            readIDs: Set(articles.filter(\.isRead).map(\.identifier)),
            favoriteIDs: Set(articles.filter(\.isFavorite).map(\.identifier))
        )
    }

    func markShown(identifiers: Set<String>) {
        guard !identifiers.isEmpty else { return }
        let descriptor = FetchDescriptor<StoredFeedArticle>(
            predicate: #Predicate<StoredFeedArticle> { identifiers.contains($0.identifier) }
        )
        let articles = (try? context.fetch(descriptor)) ?? []
        for article in articles where !article.shown {
            article.shown = true
        }
        try? context.save()
    }

    func markRead(identifier: String) {
        if let article = fetchArticle(identifier: identifier), !article.isRead {
            article.isRead = true
            try? context.save()
        }
    }

    func setFavorite(identifier: String, isFavorite: Bool) {
        if let article = fetchArticle(identifier: identifier) {
            article.isFavorite = isFavorite
            try? context.save()
        }
    }

    func isFavorite(identifier: String) -> Bool {
        fetchArticle(identifier: identifier)?.isFavorite ?? false
    }

    func fetchArticle(identifier: String) -> StoredFeedArticle? {
        var descriptor = FetchDescriptor<StoredFeedArticle>(
            predicate: #Predicate<StoredFeedArticle> { $0.identifier == identifier }
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    // MARK: - Maintenance

    /// 每个订阅源仅保留最新的 maxArticlesPerSource 条，控制本地存储体积。
    private func pruneOldArticles() {
        for source in allStoredSources() {
            let sorted = source.articles.sorted {
                switch ($0.publishedAt, $1.publishedAt) {
                case let (l?, r?): return l > r
                case (.some, .none): return true
                case (.none, .some): return false
                default: return $0.storedAt > $1.storedAt
                }
            }
            if sorted.count > maxArticlesPerSource {
                for article in sorted.dropFirst(maxArticlesPerSource) {
                    context.delete(article)
                }
            }
        }
        try? context.save()
    }
}

enum RepositoryError: LocalizedError {
    case invalidURL
    case duplicateSource

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "请输入合法的 http / https 订阅地址"
        case .duplicateSource: return "该订阅源已存在"
        }
    }
}
