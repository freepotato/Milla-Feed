import SwiftUI
import SafariServices

/// 应用内打开原文（原生 SFSafariViewController 桥接，不跳离 App）。
struct SafariView: UIViewControllerRepresentable {

    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}
