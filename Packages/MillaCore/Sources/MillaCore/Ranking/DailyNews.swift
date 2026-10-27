import Foundation

/// 每日新闻支持：小时级时段计算。
///
/// 纯函数、跨平台可测；App 层的 `DailyNewsViewModel` 只负责
/// 网络抓取、持久化与展示编排。
public enum DailyNews {

    /// 当前小时时段：key 为 "yyyy-MM-dd-HH"（该小时内唯一，用于去重抓取），
    /// name 形如 "14 点档"（页面展示）。
    public static func hourlySlot(
        now: Date,
        calendar: Calendar = .current
    ) -> (key: String, name: String) {
        var formatter: DateFormatter {
            let formatter = DateFormatter()
            formatter.calendar = calendar
            // DateFormatter 的时区独立于 calendar，必须显式同步，
            // 否则 UTC 日历下日期串会落到本地时区的另一天
            formatter.timeZone = calendar.timeZone
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "yyyy-MM-dd"
            return formatter
        }
        let hour = calendar.component(.hour, from: now)
        let key = "\(formatter.string(from: now))-\(String(format: "%02d", hour))"
        return (key, "\(hour) 点档")
    }
}
