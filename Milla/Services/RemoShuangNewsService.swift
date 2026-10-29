import Foundation
import MillaCore

/// 热摸爽主页客户端：
/// - `/api/ranked`：头条下方从 1 开始的编号榜单（分页，站点顺序即 `position`）；
/// - `/api/trends/home`：「正在升温」栏目。
struct RemoShuangNewsService: Sendable {

    private static let rankedEndpoint = URL(string: "https://remoshuang.com/api/ranked")!
    private static let trendsEndpoint = URL(string: "https://remoshuang.com/api/trends/home")!

    /// 榜单最多拉取多少页（每页 60 条），防止接口页数异常时无限请求。
    private static let maxPages = 12

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    /// 拉取完整榜单：并发请求第 2...N 页，最后按 `position` 还原站点顺序。
    func fetchRanked() async throws -> [RemoShuangRanked.Item] {
        let first = try await fetchPage(1)
        let lastPage = min(max(first.totalPages, 1), Self.maxPages)
        guard lastPage > 1 else { return first.items }

        var items = first.items
        try await withThrowingTaskGroup(of: RemoShuangRanked.Page.self) { group in
            for page in 2...lastPage {
                group.addTask { try await fetchPage(page) }
            }
            for try await page in group {
                items.append(contentsOf: page.items)
            }
        }
        return items.sorted { $0.position < $1.position }
    }

    /// 拉取「正在升温」。
    func fetchRising() async throws -> [RemoShuangRanked.Rising] {
        let data = try await fetch(Self.trendsEndpoint)
        return try RemoShuangRanked.decodeTrends(from: data)
    }

    private func fetchPage(_ page: Int) async throws -> RemoShuangRanked.Page {
        var components = URLComponents(
            url: Self.rankedEndpoint,
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [URLQueryItem(name: "page", value: String(page))]
        let data = try await fetch(components.url!)
        return try RemoShuangRanked.decodePage(from: data)
    }

    private func fetch(_ url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 20
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return data
    }
}
