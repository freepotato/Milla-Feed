import Foundation
import MillaCore

/// 首次启动预置的订阅源（全部为支持 HTTPS 的公开 RSS）。
/// 用户可随时在设置页删除或停用。
enum DefaultFeeds {

    static let sources: [FeedSource] = [
        FeedSource(
            title: "Apple Newsroom",
            url: URL(string: "https://www.apple.com/newsroom/rss-feed.rss")!,
            dailyLimit: 8,
            sampleSize: 4,
            qualityScore: 0.9
        ),
        FeedSource(
            title: "Hacker News: Front Page",
            url: URL(string: "https://hnrss.org/frontpage")!,
            dailyLimit: 10,
            sampleSize: 5,
            qualityScore: 0.75
        ),
        FeedSource(
            title: "NASA Breaking News",
            url: URL(string: "https://www.nasa.gov/feed/")!,
            dailyLimit: 6,
            sampleSize: 3,
            qualityScore: 0.85
        ),
        FeedSource(
            title: "The Verge",
            url: URL(string: "https://www.theverge.com/rss/index.xml")!,
            dailyLimit: 8,
            sampleSize: 4,
            qualityScore: 0.8
        )
    ]
}
