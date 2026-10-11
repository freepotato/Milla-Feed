import Foundation
import MillaCore

struct SyncReport: Equatable {
    var successCount: Int = 0
    var insertedCount: Int = 0
    var failures: [(title: String, message: String)] = []
}

/// 拉取并解析所有启用订阅源。
/// - 网络层只使用 URLSession；
/// - 解析优先用系统 XMLParser，失败自动回退到核心库的纯 Swift 解析器；
/// - 单个源失败不影响其他源。
@MainActor
final class FeedSyncService {

    private let session: URLSession
    private let primaryParser: FeedParsing
    private let fallbackParser: FeedParsing

    init(
        session: URLSession = {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.timeoutIntervalForRequest = 20
            configuration.waitsForConnectivity = true
            configuration.httpAdditionalHeaders = [
                "Accept": "application/rss+xml, application/atom+xml, application/xml;q=0.9, */*;q=0.8"
            ]
            return URLSession(configuration: configuration)
        }(),
        primaryParser: FeedParsing = XMLParserFeedParser(),
        fallbackParser: FeedParsing = SwiftFeedParser()
    ) {
        self.session = session
        self.primaryParser = primaryParser
        self.fallbackParser = fallbackParser
    }

    func sync(
        sources: [StoredFeedSource],
        repository: FeedRepository
    ) async -> SyncReport {
        let enabled = sources.filter(\.isEnabled)
        var report = SyncReport()

        await withTaskGroup(of: SourceResult.self) { group in
            for stored in enabled {
                let coreSource = stored.makeCoreSource()
                group.addTask { [session, primaryParser, fallbackParser] in
                    do {
                        let (data, response) = try await session.data(from: coreSource.url)
                        if let http = response as? HTTPURLResponse,
                           !(200..<300).contains(http.statusCode) {
                            return .failure(title: coreSource.title, message: "HTTP \(http.statusCode)")
                        }

                        let parsed: ParsedFeed
                        do {
                            parsed = try primaryParser.parse(data: data, source: coreSource)
                        } catch {
                            // 系统 XMLParser 失败时，用纯 Swift 实现兜底
                            parsed = try fallbackParser.parse(data: data, source: coreSource)
                        }
                        return .success(title: coreSource.title,
                                        sourceID: coreSource.id,
                                        items: parsed.items)
                    } catch let cancellation as CancellationError {
                        return .failure(title: coreSource.title, message: "已取消")
                    } catch {
                        return .failure(title: coreSource.title,
                                        message: error.localizedDescription)
                    }
                }
            }

            for await result in group {
                switch result {
                case .success(_, let sourceID, let items):
                    let inserted = repository.upsertArticles(items)
                    if let stored = sources.first(where: { $0.uuid == sourceID }) {
                        repository.markFetched(stored)
                    }
                    report.successCount += 1
                    report.insertedCount += inserted
                case .failure(let title, let message):
                    report.failures.append((title, message))
                }
            }
        }

        return report
    }

    private enum SourceResult {
        case success(title: String, sourceID: UUID, items: [FeedItem])
        case failure(title: String, message: String)
    }
}
