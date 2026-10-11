import SwiftUI

/// 首页顶部横幅。
///
/// 该视图作为 ScrollView 的第一个内容存在：信息流向下滚动时自然滑出可视区域，
/// 只有拉到最顶端时才完整显示，不额外引入滚动监听或固定导航栏。
struct TopBannerView: View {

    let onTapSettings: () -> Void

    var body: some View {
        HStack(alignment: .center) {
            Text("Milla")
                .font(.system(size: 30, weight: .heavy, design: .rounded))
                .foregroundStyle(AppColors.brand)
                .accessibilityLabel("Milla")

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
    TopBannerView(onTapSettings: {})
        .background(AppColors.screenBackground)
}
