import SwiftUI

/// 带磁盘+内存缓存与降采样的封面图视图，替换裸 AsyncImage。
/// 成功时内容回调给出 resizable 的 Image；加载中/失败时显示占位。
struct CoverImageView<Content: View, Placeholder: View>: View {

    let url: URL
    @ViewBuilder var content: (Image) -> Content
    @ViewBuilder var placeholder: () -> Placeholder

    @State private var image: UIImage?
    @State private var didFail = false

    var body: some View {
        Group {
            if let image {
                content(Image(uiImage: image).resizable())
            } else {
                placeholder()
            }
        }
        .task(id: url) {
            guard image == nil, !didFail else { return }
            if let loaded = await ImageLoader.shared.image(for: url) {
                image = loaded
            } else {
                didFail = true
            }
        }
    }
}
