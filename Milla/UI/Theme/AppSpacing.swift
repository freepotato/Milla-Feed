import CoreGraphics

/// 间距 / 圆角统一 token。不使用任何与具体设备绑定的尺寸。
enum AppSpacing {
    static let screenHorizontal: CGFloat = 16
    static let cardInner: CGFloat = 14
    static let stackVertical: CGFloat = 16
    static let bannerTop: CGFloat = 8
    static let bannerBottom: CGFloat = 12
    static let cornerRadius: CGFloat = 18
    static let imageAspectRatio: CGFloat = 9.0 / 16.0
    static let shadowRadius: CGFloat = 8
}
