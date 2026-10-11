import Foundation
import MillaCore

/// 首次启动预置的订阅源（全部为支持 HTTPS 的公开 RSS）。
/// 用户可随时在设置页删除或停用。
enum DefaultFeeds {

    static let sources: [FeedSource] = [
        FeedSource(
            title: "虎嗅",
            url: URL(string: "https://rss.aishort.top/?type=huxiu")!,
            dailyLimit: 10,
            sampleSize: 5,
            qualityScore: 0.8
        ),
        FeedSource(
            title: "少数派",
            url: URL(string: "https://sspai.com/feed")!,
            dailyLimit: 8,
            sampleSize: 4,
            qualityScore: 0.85
        ),
        FeedSource(
            title: "联合早报·中国",
            url: URL(string: "https://plink.anyfeeder.com/zaobao/realtime/china")!,
            dailyLimit: 10,
            sampleSize: 5,
            qualityScore: 0.8
        ),
        FeedSource(
            title: "知乎日报",
            url: URL(string: "https://plink.anyfeeder.com/zhihu/daily")!,
            dailyLimit: 6,
            sampleSize: 3,
            qualityScore: 0.75
        )
    ]
}
