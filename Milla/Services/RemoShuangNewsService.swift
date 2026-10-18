import Foundation
import MillaCore

/// 热摸爽「今日大事」接口客户端：一次请求拿到 Top 10 与全部分类板块。
struct RemoShuangNewsService {

    private static let endpoint = URL(string: "https://remoshuang.com/api/news/today")!

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchToday() async throws -> RemoShuangToday {
        var request = URLRequest(url: Self.endpoint)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 20
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(RemoShuangToday.self, from: data)
    }
}
