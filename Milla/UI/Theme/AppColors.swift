import SwiftUI

/// 颜色语义封装。基础色全部使用系统动态色，自动支持深色模式与 iOS 27 材质外观。
enum AppColors {

    /// Milla 品牌色（仅用于 Logo、强调控件）。
    static let brand = Color(red: 0.35, green: 0.31, blue: 0.87)

    /// 卡片底色：浅色模式下近白，深色模式下近黑。
    static let cardBackground = Color(.secondarySystemGroupedBackground)

    static let screenBackground = Color(.systemGroupedBackground)

    static let primaryText = Color(.label)
    static let secondaryText = Color(.secondaryLabel)
    static let tertiaryText = Color(.tertiaryLabel)
}
