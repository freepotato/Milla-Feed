import Foundation

/// 统一的时间展示工具（原生 RelativeDateTimeFormatter / Date.FormatStyle）。
enum DateFormatting {

    private static let relative: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        formatter.locale = Locale.current
        return formatter
    }()

    static func relativeText(from date: Date?) -> String {
        guard let date else { return "时间未知" }
        return relative.localizedString(for: date, relativeTo: Date())
    }
}
