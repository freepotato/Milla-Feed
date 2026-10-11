import SwiftUI
import UIKit
import MillaCore

/// 最小化的 HTML 正文展示：UITextView + HTML 转 AttributedString。
/// 使用系统原生控件，不引入任何第三方渲染库；滚动由外层 SwiftUI ScrollView 承担。
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
            .foregroundColor: UIColor.systemIndigo
        ]
        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        let body = html.isEmpty ? "" : html
        guard let data = body.data(using: .utf8) else {
            textView.text = body
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
            // 统一为系统动态字体与正文颜色
            let fullRange = NSRange(location: 0, length: attributed.length)
            attributed.addAttribute(
                .font,
                value: UIFont.preferredFont(forTextStyle: .body),
                range: fullRange
            )
            attributed.addAttribute(
                .foregroundColor,
                value: UIColor.label,
                range: fullRange
            )
            textView.attributedText = attributed
            textView.invalidateIntrinsicContentSize()
        } else {
            textView.text = HTMLText.plainText(from: body, maximumLength: 10_000)
        }
    }
}
