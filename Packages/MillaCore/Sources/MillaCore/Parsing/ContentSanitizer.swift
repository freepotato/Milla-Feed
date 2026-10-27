import Foundation

/// 正文净化器：清除 RSS content 里混入的原网页噪声，让详情页"直接从正文开始"。
///
/// 处理的噪声类型（来自真实源：NASA 的 `hds-secondary-navigation` 导航 div、
/// Hacker News 的 "Article URL:/Comments URL:/Points:" 样板、各站页脚链接列表）：
/// 1. HTML 注释与 script/style/svg/iframe/form/button 等非正文元素；
/// 2. class/id 命中导航、分享、页脚等特征词的元素块（按嵌套深度整块删除）；
/// 3. Hacker News 样板段落；
/// 4. 全部 `<a>` 超链接（保留链接文字——正文不可点），
///    但末尾的"查看全文/阅读原文"链接除外（它是原文入口，保留且可点）；
/// 5. 开头导航残渣与结尾的链接列表/短尾巴块；
/// 6. 清洗后遗留的空块。
///
/// 纯字符串实现（不依赖 XMLParser），macOS / Linux / iOS 行为一致，
/// 可用 milla-cli 与 XCTest 双端验证。
public enum ContentSanitizer {

    // MARK: - 主入口

    /// 清洗一段 HTML 正文。
    public static func sanitize(_ html: String) -> String {
        guard !html.isEmpty else { return html }
        var out = html
        out = removeComments(out)
        out = removeBoilerplateParagraphs(out)
        out = removeJunkClassedElements(out)
        out = removeUnwantedElements(out)
        out = unwrapAnchorsPreservingReadMore(out)
        out = dedupeRepeatedIntro(out)
        out = trimLeadingJunk(out)
        out = trimTrailingJunk(out)
        out = collapseEmptyBlocks(out)
        return out.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 删除正文中与封面同图的 `<img>`（避免详情页同一张图出现两次）。
    /// 匹配策略：img 标签文本包含封面 URL 的最后一级路径段。
    public static func removingImage(from html: String, matching cover: URL?) -> String {
        guard let cover, let key = cover.pathComponents.last, key.count > 6 else { return html }
        return mapMatches(html, pattern: "(?i)<img\\b[^>]*>") { tag, _ in
            tag.range(of: key) == nil ? .keep : .text("")
        }
    }

    // MARK: - 逐步规则

    private static func removeComments(_ html: String) -> String {
        mapMatches(html, pattern: "<!--[\\s\\S]*?-->") { _, _ in .text("") }
    }

    /// Hacker News 样板：<p>Article URL: …</p> / <p>Comments URL: …</p> /
    /// <p>Points: 4</p> / <p># Comments: 0</p>
    private static func removeBoilerplateParagraphs(_ html: String) -> String {
        let pattern = "(?is)<p\\b[^>]*>(?:(?!</p>).)*?" +
            "(article\\s+url\\s*:|comments\\s+url\\s*:|#\\s*comments|points\\s*:)" +
            "(?:(?!</p>).)*?</p>"
        return mapMatches(html, pattern: pattern) { _, _ in .text("") }
    }

    /// class/id 命中噪声特征词的元素块（含全部嵌套内容）。
    private static let junkClassPattern =
        "nav(?:igation)?|menu|share|social|sidebar|footer|comment|subscribe|" +
        "newsletter|advert|promo|related|breadcrumb|byline|site-header|tag-list|widget"

    /// 应用 class/id 检查的标签（按外层块优先）。
    private static let classCheckedTags = [
        "div", "section", "span", "p", "ul", "figure", "footer", "header", "nav", "aside"
    ]

    private static func removeJunkClassedElements(_ html: String) -> String {
        var out = html
        for tag in classCheckedTags {
            out = removeElements(tag: tag, in: out) { openTag in
                guard let attrRange = openTag.range(
                    of: "(?i)\\b(?:class|id)\\s*=\\s*[\"'][^\"']*[\"']",
                    options: .regularExpression
                ) else { return false }
                return openTag[attrRange].range(
                    of: junkClassPattern, options: .regularExpression
                ) != nil
            }
        }
        return out
    }

    /// 无论属性如何，整体删除的非正文元素。
    private static let unwantedTags = [
        "script", "style", "svg", "iframe", "noscript", "form", "button",
        "nav", "header", "footer", "aside", "object", "embed", "select", "textarea"
    ]

    private static func removeUnwantedElements(_ html: String) -> String {
        var out = html
        for tag in unwantedTags {
            out = removeElements(tag: tag, in: out) { _ in true }
        }
        // input 为空元素，只删标签本身
        return mapMatches(out, pattern: "(?i)<input\\b[^>]*>") { _, _ in .text("") }
    }

    /// 删除全部 <a> 标签，仅保留内部内容（可能是文字，也可能是 <img>）；
    /// 例外：末尾的"查看全文 / 阅读原文"链接（文本 ≤ 12 字、位于最后 120 个字符内）
    /// 保留原标签——它是原文入口，需要可点。
    private static func unwrapAnchorsPreservingReadMore(_ html: String) -> String {
        mapMatches(html, pattern: "(?is)<a\\b[^>]*>([\\s\\S]*?)</a>") { match, range in
            let inner = match
                .replacingOccurrences(
                    of: "(?is)^<a\\b[^>]*>|</a>$", with: "", options: .regularExpression
                )
            let text = HTMLText.plainText(from: String(match), maximumLength: 100)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let isReadMore = text.range(
                of: "查看全文|阅读原文|阅读全文",
                options: .regularExpression
            ) != nil && text.count <= 12
            let nearEnd = html.distance(from: range.upperBound, to: html.endIndex) <= 120
            return (isReadMore && nearEnd) ? .keep : .text(String(inner))
        }
    }

    /// 重复导入语去除：部分源（如虎嗅）正文开头先放一段"编者导入语"，
    /// 隔一行作者/来源后，正文又以完全相同的文字开篇。
    ///
    /// 检测规则（保守，避免误删）：
    /// 1. 跳过开头的封面/媒体块，取其后的内容：
    ///    - 形态 A（虎嗅）：导入语是没有标签包裹的裸文本，结束于下一个块级标签；
    ///    - 形态 B：导入语是 1~2 个连续文本块（p/div/blockquote/h）；
    /// 2. 候选可见文本 ≥30 字且 ≤600 字；
    /// 3. 候选之后的剩余正文若包含导入语前 30 字，判定为重复，删除候选
    ///   （来源行不在候选内，保留）。
    private static func dedupeRepeatedIntro(_ html: String) -> String {
        guard let blockRegex = try? NSRegularExpression(
            pattern: "(?is)<(p|div|blockquote|h[1-6]|ul|ol|pre|table|section)\\b[^>]*>.*?</\\1>"
        ) else { return html }
        let ns = html as NSString

        // 1. 跳过开头的媒体块（figure / img）与空白，确定正文起点
        var pos = html.startIndex
        let mediaRegex = try? NSRegularExpression(
            pattern: "(?is)^\\s*(?:<figure\\b.*?</figure>|<img\\b[^>]*>|<!--.*?-->)+\\s*"
        )
        if let m = mediaRegex?.firstMatch(
            in: html, range: NSRange(location: 0, length: ns.length)
        ), let r = Range(m.range, in: html) {
            pos = r.upperBound
        }

        // 2a. 形态 A：起点到下一个块级标签之间的裸文本
        if let nextBlock = html.range(
            of: "(?is)<(p|div|blockquote|h[1-6]|ul|ol|pre|table|section|figure)\\b",
            options: .regularExpression,
            range: pos..<html.endIndex
        ) {
            let segment = html[pos..<nextBlock.lowerBound]
            if let removed = removeIfRepeated(
                String(segment),
                candidateRanges: [pos..<nextBlock.lowerBound],
                in: html
            ) {
                return removed
            }
        }

        // 2b. 形态 B：前 1~2 个连续文本块
        let blockRanges = blockRegex.matches(
            in: html, range: NSRange(location: 0, length: ns.length)
        ).compactMap { Range($0.range, in: html) }
        guard blockRanges.count >= 2 else { return html }

        var startPos: Int?
        var skipped = 0
        for (index, range) in blockRanges.enumerated() {
            let block = String(html[range])
            if block.range(of: "<img", options: .caseInsensitive) != nil
                || normalizeWhitespace(
                    HTMLText.plainText(from: block, maximumLength: 2_000)
                ).count < 20 {
                skipped += 1
                if skipped > 3 { break }
                continue
            }
            startPos = index
            break
        }
        guard let startPos else { return html }

        for blockCount in 1...2 {
            let endPos = startPos + blockCount
            guard endPos <= blockRanges.count else { return html }
            let ranges = Array(blockRanges[startPos..<endPos])
            if let removed = removeIfRepeated(
                ranges.map { String(html[$0]) }.joined(),
                candidateRanges: ranges,
                in: html
            ) {
                return removed
            }
        }
        return html
    }

    /// 候选文本在其后的正文中重复时，删除给定范围，返回净化结果；否则 nil。
    /// 比较时移除全部空白：部分源（虎嗅）会把重复段拆进多个 `<p>`，
    /// plainText 跨块会插入空白，导致带空白的前缀匹配失败。
    private static func removeIfRepeated(
        _ candidateText: String,
        candidateRanges: [Range<String.Index>],
        in html: String
    ) -> String? {
        let intro = normalizeWhitespace(
            HTMLText.plainText(from: candidateText, maximumLength: 4_000)
        )
        guard intro.count >= 30, intro.count <= 600,
              let last = candidateRanges.last else { return nil }
        let prefixSquashed = squashWhitespace(String(intro.prefix(30)))
        let remainderSquashed = squashWhitespace(
            HTMLText.plainText(from: String(html[last.upperBound...]), maximumLength: 200_000)
        )
        guard remainderSquashed.contains(prefixSquashed) else { return nil }

        var out = html
        for range in candidateRanges.reversed() {
            out.removeSubrange(range)
        }
        return out
    }

    /// 移除全部空白（跨段落重复匹配用）。
    private static func squashWhitespace(_ text: String) -> String {
        String(text.unicodeScalars.filter {
            !CharacterSet.whitespacesAndNewlines.contains($0)
        })
    }

    private static func normalizeWhitespace(_ text: String) -> String {
        text.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    /// 开头修剪：第一个"实质内容块"（p/figure/img/h/blockquote/list/pre/table）之前
    /// 的残渣，若不含图片且可见文本 ≤ 300 字符，整段丢弃。
    private static func trimLeadingJunk(_ html: String) -> String {
        let pattern = "(?i)<(p|figure|img|h[1-6]|blockquote|ul|ol|pre|table)\\b"
        guard let first = firstMatchRange(of: pattern, in: html),
              first.lowerBound > html.startIndex else { return html }
        let prefix = String(html[html.startIndex..<first.lowerBound])
        if prefix.range(of: "<img", options: .caseInsensitive) != nil { return html }
        let visible = HTMLText.plainText(from: prefix, maximumLength: 1_000)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !visible.isEmpty, visible.count <= 300 else { return html }
        return String(html[first.lowerBound...])
    }

    /// 结尾修剪：反复删除尾部可见文本 ≤ 60 字符、不含图片，或命中页脚关键词的块。
    /// 守卫：整篇可见文本 ≤ 200 字符时不修剪，避免把短正文的唯一段落当尾巴误删。
    private static func trimTrailingJunk(_ html: String) -> String {
        let totalVisible = HTMLText.plainText(from: html, maximumLength: 100_000)
            .trimmingCharacters(in: .whitespacesAndNewlines).count
        guard totalVisible > 200 else { return html }
        var out = html
        let tailPattern = "(?is)<(p|div|figure)\\b[^>]*>(?:(?!</\\1>).)*?</\\1>\\s*$"
        let junkWords = "(?i)^\\s*(read more|filed under|tags?\\s*[:：]|share|follow|subscribe|" +
            "advertisement|related|comments|leave a comment|post navigation|via\\s)"
        for _ in 0..<6 {
            var didReplace = false
            out = mapMatches(out, pattern: tailPattern) { block, _ in
                // $ 锚定只能在单遍扫描里命中一个尾部块
                let visible = HTMLText.plainText(from: String(block), maximumLength: 400)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                let shortNoImage = visible.count <= 60 &&
                    block.range(of: "<img", options: .caseInsensitive) == nil
                let keywordHit = visible.range(of: junkWords, options: .regularExpression) != nil
                // 末尾"查看全文/阅读原文"链接是特意保留的原文入口，不当短尾巴修剪
                let readMoreKept = block.range(of: "<a\\b", options: .regularExpression) != nil &&
                    visible.range(
                        of: "查看全文|阅读原文|阅读全文", options: .regularExpression
                    ) != nil
                if (shortNoImage || keywordHit) && !readMoreKept {
                    didReplace = true
                    return .text("")
                }
                return .keep
            }
            if !didReplace { break }
        }
        return out
    }

    /// 清洗后遗留的空块折叠。
    private static func collapseEmptyBlocks(_ html: String) -> String {
        var out = html
        let pattern = "(?is)<(p|div|figure|span)\\b[^>]*>\\s*</\\1>"
        for _ in 0..<3 {
            var didReplace = false
            out = mapMatches(out, pattern: pattern) { _, _ in
                didReplace = true
                return .text("")
            }
            if !didReplace { break }
        }
        return out
    }

    // MARK: - 标签级删除（深度计数，正确处理嵌套同名标签）

    /// 对每个 `<tag ...>` 调用 `keep`；不需要保留时连同配对的 `</tag>`（按嵌套
    /// 深度）整块删除。
    private static func removeElements(
        tag: String,
        in html: String,
        keep: (Substring) -> Bool
    ) -> String {
        mapMatches(html, pattern: "(?i)<\(tag)\\b([^>]*?)(/?)>") { match, range in
            guard keep(match) else { return .keep }
            if match.range(of: "/\\s*>$", options: .regularExpression) != nil {
                return .text("")  // 自闭合
            }
            if let close = matchingCloseRange(forOpenAt: range, tag: tag, in: html) {
                return .drop(range.lowerBound..<close.upperBound)
            }
            return .text("")  // 畸形输入：只删开标签
        }
    }

    // MARK: - 扫描引擎

    private enum Action {
        case keep
        case text(String)
        case drop(Range<String.Index>)
    }

    /// 从左到右单遍扫描全部匹配；`.drop` 直接把游标跳到删除范围末尾，
    /// 因此被删块内部的其他匹配自动跳过。
    private static func mapMatches(
        _ html: String,
        pattern: String,
        map: (Substring, Range<String.Index>) -> Action
    ) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return html }
        let ns = html as NSString
        let matches = regex.matches(in: html, range: NSRange(location: 0, length: ns.length))
        guard !matches.isEmpty else { return html }

        var out = ""
        var cursor = html.startIndex
        var didChange = false

        for m in matches {
            guard let range = Range(m.range, in: html), range.lowerBound >= cursor else { continue }
            out += html[cursor..<range.lowerBound]
            let substring = html[range]
            switch map(substring, range) {
            case .keep:
                out += substring
            case .text(let text):
                out += text
                didChange = true
            case .drop(let dropRange):
                didChange = true
                cursor = dropRange.upperBound
                continue
            }
            cursor = range.upperBound
        }
        out += html[cursor...]
        return didChange ? out : html
    }

    private static func firstMatchRange(of pattern: String, in html: String) -> Range<String.Index>? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let ns = html as NSString
        guard let match = regex.firstMatch(in: html, range: NSRange(location: 0, length: ns.length)) else {
            return nil
        }
        return Range(match.range, in: html)
    }

    /// 从开标签之后按嵌套深度找到配对的 `</tag>`。
    private static func matchingCloseRange(
        forOpenAt open: Range<String.Index>,
        tag: String,
        in html: String
    ) -> Range<String.Index>? {
        guard let regex = try? NSRegularExpression(pattern: "(?i)<(/?)\(tag)\\b[^>]*?>") else {
            return nil
        }
        let ns = html as NSString
        var depth = 1
        for m in regex.matches(in: html, range: NSRange(location: 0, length: ns.length)) {
            guard let range = Range(m.range, in: html), range.lowerBound >= open.upperBound else { continue }
            let isClose = m.range(at: 1).location != NSNotFound &&
                ns.substring(with: m.range(at: 1)) == "/"
            depth += isClose ? -1 : 1
            if depth == 0 { return range }
        }
        return nil
    }
}
