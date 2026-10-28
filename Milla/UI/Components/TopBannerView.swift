import SwiftUI

/// 首页顶部横幅：Milla 品牌字 + 搜索框 + 收藏入口 + 设置。
struct TopBannerView: View {

    @Binding var searchText: String
    let onTapFavorites: () -> Void
    let onTapSettings: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Text("Milla")
                .font(.system(size: 24, weight: .heavy, design: .rounded))
                .foregroundStyle(AppColors.brand)

            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppColors.tertiaryText)
                TextField("搜索文章", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.subheadline)
                    .foregroundStyle(AppColors.primaryText)
                    .submitLabel(.search)
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(AppColors.tertiaryText)
                    }
                    .accessibilityLabel("清除搜索")
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(AppColors.cardBackground)
            .clipShape(Capsule())

            Button(action: onTapFavorites) {
                Image(systemName: "star.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.yellow)
                    .frame(width: 34, height: 34)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("收藏")

            Button(action: onTapSettings) {
                Image(systemName: "gearshape")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AppColors.primaryText)
                    .frame(width: 34, height: 34)
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
    TopBannerView(searchText: .constant(""), onTapFavorites: {}, onTapSettings: {})
        .background(AppColors.screenBackground)
}
