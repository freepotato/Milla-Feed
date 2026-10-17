import Foundation
import UIKit

/// 封面图加载器：解决裸 AsyncImage 的三大问题——
/// 1. 原图全尺寸解码（几 MB 的图缩到 180pt 显示）→ 用 ImageIO 降采样到目标像素；
/// 2. 磁盘缓存依赖服务端缓存头，图床不带头就每次重下 → 自建 URLCache 强制缓存；
/// 3. 同一 URL 多处并发重复下载 → actor 内合并 in-flight 请求。
actor ImageLoader {

    static let shared = ImageLoader()

    /// 统一降采样上限：兼顾卡片（180pt 高）与详情封面（上限 480pt），@3x 屏足够清晰。
    static let maxPixel = 1600

    private let memoryCache = NSCache<NSURL, UIImage>()
    private let session: URLSession
    private var inFlight: [NSURL: Task<UIImage?, Never>] = [:]

    private init() {
        let cacheDirectory = FileManager.default
            .urls(for: .cachesDirectory, in: .userDomainMask).first?
            .appendingPathComponent("CoverImages", isDirectory: true)
        let cache = URLCache(
            memoryCapacity: 32 * 1024 * 1024,
            diskCapacity: 256 * 1024 * 1024,
            directory: cacheDirectory
        )
        let configuration = URLSessionConfiguration.default
        configuration.urlCache = cache
        // 封面图几乎不变，命中磁盘缓存就直接用（离线也能显示）
        configuration.requestCachePolicy = .returnCacheDataElseLoad
        configuration.timeoutIntervalForRequest = 20
        session = URLSession(configuration: configuration)
        memoryCache.totalCostLimit = 48 * 1024 * 1024
    }

    /// 加载并按 maxPixel 降采样；失败（网络错误 / 非 2xx / 解码失败）返回 nil。
    func image(for url: URL) async -> UIImage? {
        let key = url as NSURL
        if let cached = memoryCache.object(forKey: key) {
            return cached
        }
        if let existing = inFlight[key] {
            return await existing.value
        }
        let task = Task<UIImage?, Never> { [session] in
            do {
                let (data, response) = try await session.data(from: url)
                guard let http = response as? HTTPURLResponse,
                      (200..<300).contains(http.statusCode) else { return nil }
                return Self.downsample(data: data, maxPixel: Self.maxPixel)
            } catch {
                return nil
            }
        }
        inFlight[key] = task
        let result = await task.value
        inFlight[key] = nil
        if let result {
            memoryCache.setObject(
                result, forKey: key,
                cost: result.cgImage.map { $0.bytesPerRow * $0.height } ?? 0
            )
        }
        return result
    }

    /// ImageIO 缩略图解码：不解全尺寸位图，直接按目标像素解码，内存与耗时都低一个量级。
    private nonisolated static func downsample(data: Data, maxPixel: Int) -> UIImage? {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions) else {
            return nil
        }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }
}
