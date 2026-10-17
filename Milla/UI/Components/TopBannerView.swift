import SwiftUI

/// 首页顶部横幅。
///
/// 该视图作为 ScrollView 的第一个内容存在：信息流向下滚动时自然滑出可视区域，
/// 只有拉到最顶端时才完整显示，不额外引入滚动监听或固定导航栏。
///
/// 左上角 Milla logo 可点击：在"信息流 / 每日新闻"之间切换。
struct TopBannerView: View {

    /// 当前是否处于每日新闻页。
    let isDailyNews: Bool
    let onTapLogo: () -> Void
    let onTapSettings: () -> Void

    var body: some View {
        HStack(alignment: .center) {
            Button(action: onTapLogo) {
                HStack(alignment: .center, spacing: 8) {
                    Text("Milla")
                        .font(.system(size: 30, weight: .heavy, design: .rounded))
                        .foregroundStyle(AppColors.brand)
                    if isDailyNews {
                        HStack(spacing: 2) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 11, weight: .bold))
                            Text("信息流")
                                .font(.caption.weight(.medium))
                        }
                        .foregroundStyle(AppColors.secondaryText)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(AppColors.cardBackground)
                        .clipShape(Capsule())
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isDailyNews ? "返回信息流" : "打开每日新闻")

            Spacer()

            Button(action: onTapSettings) {
                Image(systemName: "gearshape")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(AppColors.primaryText)
                    .frame(width: 38, height: 38)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("设置")
        }
        .padding(.horizontal, AppSpacing.screenHorizontal)
        .padding(.top, AppSpacing.bannerTop)
        .padding(.bottom, AppSpacing.bannerBottom)
    }
}

#Preview {
    VStack(spacing: 0) {
        TopBannerView(isDailyNews: false, onTapLogo: {}, onTapSettings: {})
        TopBannerView(isDailyNews: true, onTapLogo: {}, onTapSettings: {})
    }
    .background(AppColors.screenBackground)
}
