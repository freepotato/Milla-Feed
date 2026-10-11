import Foundation

/// HTML / XML 文本工具：实体解码、标签剥离、封面图提取。
/// 只覆盖 Feed 场景所需的最小集合，不引入任何第三方库。
public enum HTMLText {

    /// 将 HTML 转为纯文本摘要：去标签、解码实体、折叠空白。
    public static func plainText(
        from html: String,
        maximumLength: Int = 240
    ) -> String {
        guard !html.isEmpty else { return "" }

        var result = ""
        result.reserveCapacity(html.count)

        let scalars = html.unicodeScalars
        var index = scalars.startIndex
        var isSkipping = false // <script>/<style> 内容

        while index < scalars.endIndex {
            let scalar = scalars[index]

            if scalar == "<" {
                // 读取整个标签
                let tagStart = index
                while index < scalars.endIndex, scalars[index] != ">" {
                    scalars.formIndex(after: &index)
                }
                if index < scalars.endIndex {
                    scalars.formIndex(after: &index) // 跳过 ">"
                }
                let rawTag = String(String.UnicodeScalarView(scalars[tagStart..<index]))
                    .lowercased()
                let name = rawTag
                    .dropFirst()
                    .split(whereSeparator: { $0 == " " || $0 == "\t" || $0 == "/" || $0 == "\n" })
                    .first
                    .map(String.init) ?? ""

                if name == "script" || name == "style" {
                    isSkipping = true
                } else if name == "/script" || name == "/style" {
                    isSkipping = false
                } else if name == "br" || name == "p" || name == "div" || name == "li" {
                    result += "\n"
                }
                continue
            }

            if !isSkipping {
                result.append(Character(scalar))
            }
            scalars.formIndex(after: &index)
        }

        result = decodeEntities(in: result)

        // 折叠空白
        result = result
            .replacingOccurrences(of: "\u{00a0}", with: " ")
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if result.count > maximumLength {
            let end = result.index(result.startIndex, offsetBy: maximumLength)
            result = String(result[..<end]).trimmingCharacters(in: .whitespacesAndNewlines) + "…"
        }
        return result
    }

    /// 从 HTML 片段中提取第一张图片的地址（<img src="...">）。
    public static func firstImageURL(in html: String) -> URL? {
        guard let range = html.range(of: "<img", options: .caseInsensitive) else {
            return nil
        }
        let remaining = String(html[range.lowerBound...])
        guard let srcRange = remaining.range(
            of: #"(?i)\bsrc\s*=\s*['"]([^'"]+)['"]"#,
            options: .regularExpression
        ) else {
            return nil
        }
        let raw = String(remaining[srcRange])
        // 取出引号中的部分
        let quoteChars: Set<Character> = ["'", "\""]
        guard let firstQuote = raw.firstIndex(where: { quoteChars.contains($0) }) else {
            return nil
        }
        let afterFirst = raw.index(after: firstQuote)
        guard let secondQuote = raw[afterFirst...].firstIndex(where: { quoteChars.contains($0) }) else {
            return nil
        }
        let address = decodeEntities(in: String(raw[afterFirst..<secondQuote]))
            .trimmingCharacters(in: .whitespaces)
        return URL(string: address)
    }

    /// 解码常见 XML/HTML 实体（含十进制 / 十六进制数字实体）。
    public static func decodeEntities(in string: String) -> String {
        guard string.contains("&") else { return string }

        let named: [String: String] = [
            "amp": "&",
            "lt": "<",
            "gt": ">",
            "quot": "\"",
            "apos": "'",
            "nbsp": "\u{00a0}",
            "copy": "\u{00a9}",
            "reg": "\u{00ae}",
            "trade": "\u{2122}",
            "hellip": "\u{2026}",
            "mdash": "\u{2014}",
            "ndash": "\u{2013}",
            "lsquo": "\u{2018}",
            "rsquo": "\u{2019}",
            "ldquo": "\u{201c}",
            "rdquo": "\u{201d}"
        ]

        var result = ""
        result.reserveCapacity(string.count)
        let scalars = string.unicodeScalars
        var index = scalars.startIndex

        while index < scalars.endIndex {
            if scalars[index] == "&" {
                let start = index
                var end = scalars.index(after: start)
                while end < scalars.endIndex, scalars[end] != ";" {
                    scalars.formIndex(after: &end)
                }
                guard end < scalars.endIndex else {
                    // 未闭合的裸 "&"（例如 "Hello & Bye"）：剩余文本原样输出
                    result.append(String(String.UnicodeScalarView(scalars[index...])))
                    index = scalars.endIndex
                    break
                }

                var entity = String(String.UnicodeScalarView(scalars[scalars.index(after: start)..<end]))
                var decoded: String?

                if entity.hasPrefix("#") {
                    entity.removeFirst()
                    let radix: Int
                    if entity.lowercased().hasPrefix("x") {
                        entity.removeFirst()
                        radix = 16
                    } else {
                        radix = 10
                    }
                    if let code = UInt32(entity, radix: radix), let scalar = Unicode.Scalar(code) {
                        decoded = String(Character(scalar))
                    }
                } else {
                    decoded = named[entity.lowercased()]
                }

                result.append(decoded ?? "")
                index = scalars.index(after: end) // 跳过 ";"
            } else {
                result.append(Character(scalars[index]))
                scalars.formIndex(after: &index)
            }
        }
        return result
    }
}
