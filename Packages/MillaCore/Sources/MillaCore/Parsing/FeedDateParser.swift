import Foundation

/// Feed 时间解析：同时支持 RFC 822（RSS）与 ISO 8601（Atom / RDF / JSON 风格）。
public enum FeedDateParser {

    private static let iso8601: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let iso8601NoFraction: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private static let rfc822Formatters: [DateFormatter] = {
        let patterns = [
            "EEE, d MMM yyyy HH:mm:ss zzz",
            "EEE, d MMM yyyy HH:mm:ss z",
            "EEE, d MMM yyyy HH:mm zzz",
            "d MMM yyyy HH:mm:ss zzz",
            "yyyy-MM-dd HH:mm:ss"
        ]
        return patterns.map { pattern in
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(abbreviation: "GMT")
            formatter.dateFormat = pattern
            return formatter
        }
    }()

    public static func date(from string: String) -> Date? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if trimmed.contains("-") || trimmed.contains("T") {
            if let date = iso8601.date(from: trimmed) { return date }
            if let date = iso8601NoFraction.date(from: trimmed) { return date }
        }
        for formatter in rfc822Formatters {
            if let date = formatter.date(from: trimmed) { return date }
        }
        return nil
    }
}
