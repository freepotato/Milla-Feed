import SwiftUI

/// 首页顶部横幅：左侧 Milla 品牌字，右侧设置按钮。
///
/// 信息流与每日新闻现由底部 Tab 栏切换，此处 logo 仅作品牌展示。
struct TopBannerView: View {

    let onTapSettings: () -> Void

    var body: some View {
        HStack(alignment: .center) {
            Text("Milla")
                .font(.system(size: 30, weight: .heavy, design: .rounded))
                .foregroundStyle(AppColors.brand)

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
