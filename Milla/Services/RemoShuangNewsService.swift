import Foundation
import MillaCore

/// 热摸爽主页热榜客户端：一次请求拿到全部来源的分组榜单。
struct RemoShuangNewsService {

    private static let endpoint = URL(string: "https://remoshuang.com/api/hot")!

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchHot() async throws -> [RemoShuangHot.Source] {
        var request = URLRequest(url: Self.endpoint)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 20
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return try RemoShuangHot.decodeSources(from: data)
    }
}
