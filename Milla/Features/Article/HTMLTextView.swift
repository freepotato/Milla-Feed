import SwiftUI
import UIKit
import MillaCore

/// 最小化的 HTML 正文展示：UITextView + HTML 转 AttributedString。
/// 使用系统原生控件，不引入任何第三方渲染库；滚动由外层 SwiftUI ScrollView 承担。
///
/// 排版策略：
/// - 用一段阅读器 CSS 约束布局（图片 max-width、行高、引用/代码块样式），
///   保留 h1/h2/strong 等语义层级，不再统一覆盖字体；
/// - 解析器写死的文字颜色统一替换为动态 label 色，深浅色模式均可读。
struct HTMLTextView: UIViewRepresentable {

    let html: String

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.isScrollEnabled = false
        textView.backgroundColor = .clear
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.adjustsFontForContentSizeCategory = true
        textView.dataDetectorTypes = [.link]
        textView.linkTextAttributes = [
            .foregroundColor: UIColor(red: 0.35, green: 0.31, blue: 0.87, alpha: 1)
        ]
        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        let body = html.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty, let data = Self.readerDocument(body).data(using: .utf8) else {
            textView.text = HTMLText.plainText(from: body, maximumLength: 10_000)
            return
        }

        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]

        if let attributed = try? NSMutableAttributedString(
            data: data,
            options: options,
            documentAttributes: nil
        ) {
            // HTML 解析器会给文字写死颜色（深色模式下黑底黑字），
            // 统一替换为动态 label 色；链接颜色交给 linkTextAttributes。
            let fullRange = NSRange(location: 0, length: attributed.length)
            attributed.enumerateAttribute(.foregroundColor, in: fullRange) { value, range, _ in
                guard value != nil else { return }
                attributed.addAttribute(.foregroundColor, value: UIColor.label, range: range)
            }
            textView.attributedText = attributed
            textView.invalidateIntrinsicContentSize()
        } else {
            textView.text = HTMLText.plainText(from: body, maximumLength: 10_000)
        }
    }

    /// 阅读器排版模板：约束图片宽度、统一行高与块级元素样式。
    private static func readerDocument(_ body: String) -> String {
        """
        <html><head><meta charset="utf-8"><style>
        body { font-family: -apple-system; font-size: 17px; line-height: 1.65;
               margin: 0; padding: 0; word-wrap: break-word; }
        img, video { max-width: 100%; height: auto; border-radius: 10px; }
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
