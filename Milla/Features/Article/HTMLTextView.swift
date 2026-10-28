import SwiftUI
import UIKit
import MillaCore

/// 最小化的 HTML 正文展示：UITextView + HTML 转 AttributedString。
/// 使用系统原生控件，不引入任何第三方渲染库；滚动由外层 SwiftUI ScrollView 承担。
///
/// 排版策略：
/// - 用一段阅读器 CSS 约束布局（行高、引用/代码块样式），保留 h1/h2/strong 等语义层级；
/// - 解析器写死的文字颜色统一替换为动态 label 色，深浅色模式均可读；
/// - 正文不含任何可点超链接（净化器已剥离 <a>，此处再关闭数据检测并移除 .link 属性）；
/// - 内嵌图片宽度不超过版心（NSAttributedString 的 HTML 导入不认 CSS max-width，
///   需要手动缩放 NSTextAttachment 的 bounds）。
struct HTMLTextView: UIViewRepresentable {

    let html: String
    /// 点击正文中保留的链接（如末尾"查看全文"）时回调，由外层决定如何打开。
    var onOpenLink: ((URL) -> Void)? = nil

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.isScrollEnabled = false
        textView.backgroundColor = .clear
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.textContainer.widthTracksTextView = true
        textView.adjustsFontForContentSizeCategory = true
        textView.dataDetectorTypes = [] // 只响应显式保留的 <a> 链接
        textView.delegate = context.coordinator
        return textView
    }

    /// 关键：永远不要向 SwiftUI 申报超过给定提议的宽度。
    /// 默认实现会直接采用 UITextView 的 intrinsicContentSize——在 HTML 属性串
    /// 设置完成前，其宽度是「未换行的整行宽度」（可达数千 pt），会把外层
    /// ScrollView/VStack 横向撑爆，导致整页内容被推出可视区域。
    /// 这里用确定宽度向 UIKit 量取换行后的高度。
    func sizeThatFits(
        _ proposal: ProposedViewSize,
        uiView: UITextView,
        context: Context
    ) -> CGSize? {
        let width = proposal.width ?? uiView.superview?.bounds.width ?? 0
        guard width > 1 else { return nil }
        Self.capAttachmentWidths(in: uiView, maxWidth: width)
        let measured = uiView.sizeThatFits(
            CGSize(width: width, height: .greatestFiniteMagnitude)
        )
        return CGSize(width: width, height: measured.height)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    /// 跟踪最新一次渲染请求：异步解析完成时若已有更新的请求，直接丢弃结果。
    final class Coordinator: NSObject, UITextViewDelegate {
        var generation = 0
        var onOpenLink: ((URL) -> Void)?

        /// iOS 17 起旧的 shouldInteractWith 已废弃，改用文字项的主操作回调。
        /// 只接管链接：点击"查看全文"交给外层打开；非链接文字保持系统默认行为。
        func textView(
            _ textView: UITextView,
            primaryActionFor textItem: UITextItem,
            defaultAction: UIAction
        ) -> UIAction? {
            guard case .link(let url) = textItem.content else {
                return defaultAction
            }
            return UIAction { [weak self] _ in
                self?.onOpenLink?(url)
            }
        }
    }

    /// NSAttributedString 是不可变对象，后台解析完成后跨线程读取是安全的；
    /// 用 @unchecked 包装满足 @Sendable 闭包的捕获检查（Swift 6 下未包装会直接报错）。
    private struct SendableAttributedText: @unchecked Sendable {
        let value: NSAttributedString?
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        context.coordinator.generation += 1
        let generation = context.coordinator.generation
        context.coordinator.onOpenLink = onOpenLink

        let body = html.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty, let data = Self.readerDocument(body).data(using: .utf8) else {
            textView.text = HTMLText.plainText(from: body, maximumLength: 10_000)
            return
        }

        // HTML 导入（含远程图片附件抓取）非常耗时，放后台解析，
        // 完成后回主线程一次性设置——避免长文打开时整页卡住。
        let coordinator = context.coordinator
        Task.detached(priority: .userInitiated) { [textView, coordinator] in
            let rendered = SendableAttributedText(value: Self.renderAttributed(from: data))
            await MainActor.run {
                guard generation == coordinator.generation else { return }
                if let rendered = rendered.value {
                    textView.attributedText = rendered
                } else {
                    textView.text = HTMLText.plainText(from: body, maximumLength: 10_000)
                }
                textView.invalidateIntrinsicContentSize()
            }
        }
    }

    /// 后台执行：HTML -> AttributedString，并做链接剥离与颜色归一。
    private nonisolated static func renderAttributed(from data: Data) -> NSAttributedString? {
        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]
        guard let attributed = try? NSMutableAttributedString(
            data: data,
            options: options,
            documentAttributes: nil
        ) else { return nil }

        let fullRange = NSRange(location: 0, length: attributed.length)
        // 剥离超链接属性，但保留"查看全文/阅读原文"链接（净化器在末尾特意留下的原文入口）
        attributed.enumerateAttribute(.link, in: fullRange) { value, range, _ in
            guard value != nil else { return }
            let text = (attributed.string as NSString).substring(with: range)
            let isReadMore = text.range(
                of: "查看全文|阅读原文|阅读全文",
                options: .regularExpression
            ) != nil
            if !isReadMore {
                attributed.removeAttribute(.link, range: range)
            }
        }
        // HTML 解析器会给文字写死颜色（深色模式下黑底黑字），
        // 统一替换为动态 label 色。
        attributed.enumerateAttribute(.foregroundColor, in: fullRange) { value, range, _ in
            guard value != nil else { return }
            attributed.addAttribute(.foregroundColor, value: UIColor.label, range: range)
        }
        return attributed
    }

    /// 把超过版心宽度的图片附件等比缩小。
    private static func capAttachmentWidths(in textView: UITextView, maxWidth: CGFloat) {
        guard let attributed = textView.attributedText, attributed.length > 0 else { return }
        let fullRange = NSRange(location: 0, length: attributed.length)
        attributed.enumerateAttribute(.attachment, in: fullRange) { value, _, _ in
            guard let attachment = value as? NSTextAttachment else { return }
            var width = attachment.bounds.width
            var height = attachment.bounds.height
            if width <= 0, let image = attachment.image {
                width = image.size.width
                height = image.size.height
            }
            guard width > maxWidth, width > 0 else { return }
            let scale = maxWidth / width
            attachment.bounds = CGRect(
                x: 0, y: 0,
                width: width * scale,
                height: height * scale
            )
        }
    }

    /// 阅读器排版模板：统一行高与块级元素样式。
    private static func readerDocument(_ body: String) -> String {
        """
        <html><head><meta charset="utf-8"><style>
        body { font-family: -apple-system; font-size: 17px; line-height: 1.65;
               margin: 0; padding: 0; word-wrap: break-word; }
        img, video { max-width: 100%; height: auto; border-radius: 10px; }
        a { color: #6C5CE7; text-decoration: none; font-weight: 600; }
        h1 { font-size: 24px; } h2 { font-size: 21px; } h3 { font-size: 18px; }
        h1, h2, h3, h4 { line-height: 1.3; margin: 18px 0 8px; }
        p { margin: 0 0 12px; }
        blockquote { margin: 0 0 12px 4px; padding: 2px 0 2px 12px;
                     border-left: 3px solid rgba(120,120,128,.45); }
        pre { overflow-x: auto; padding: 10px; border-radius: 8px;
              background: rgba(120,120,128,.14); white-space: pre-wrap;
              font-family: ui-monospace, Menlo; font-size: 14px; }
        code { font-family: ui-monospace, Menlo; font-size: 15px; }
        ul, ol { padding-left: 22px; }
        figure { margin: 0 0 12px; }
        figcaption { font-size: 13px; opacity: .7; }
        hr { border: none; border-top: 1px solid rgba(120,120,128,.3); margin: 16px 0; }
        </style></head><body>\(body)</body></html>
        """
    }
}
