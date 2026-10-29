import CoreGraphics

/// 间距 / 圆角统一 token。不使用任何与具体设备绑定的尺寸。
enum AppSpacing {
    /// 列表页左右留白：与文章页正文（20）一致，右侧留出可拖动系统滚动条的空白。
    static let screenHorizontal: CGFloat = 20
    static let cardInner: CGFloat = 14
    static let stackVertical: CGFloat = 16
    static let bannerTop: CGFloat = 8
    static let bannerBottom: CGFloat = 12
    static let cornerRadius: CGFloat = 18
    static let imageAspectRatio: CGFloat = 9.0 / 16.0
    static let shadowRadius: CGFloat = 8
}
