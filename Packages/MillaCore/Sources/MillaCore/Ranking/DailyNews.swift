import Foundation

/// 每日新闻支持：时段计算。
///
/// 纯函数、跨平台可测；App 层的 `DailyNewsViewModel` 只负责
/// 网络抓取、持久化与展示编排。
public enum DailyNews {

    /// 当前时段；0:00–7:00 返回 nil（该时段没有自己的新闻批次）。
    /// - 上午版：7:00–12:00；午后版：12:00–24:00。
    public static func currentSlot(
        now: Date,
        calendar: Calendar = .current
    ) -> (key: String, name: String)? {
        let hour = calendar.component(.hour, from: now)
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
        let day = formatter.string(from: now)
        switch hour {
        case 7..<12: return ("\(day)-am", "上午版")
        case 12..<24: return ("\(day)-pm", "午后版")
        default: return nil
        }
    }
}
