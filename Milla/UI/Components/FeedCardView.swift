import SwiftUI
import MillaCore

/// 信息流卡片：封面图 + 标题 + 摘要 + 来源 / 时间。
/// 布局参考公众号信息流，全部使用原生 SwiftUI 组件。
struct FeedCardView: View {

    let ranked: RankedFeedItem
    let sourceTitle: String
    let isRead: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            cover

            Text(ranked.item.title)
                .font(.headline)
                .foregroundStyle(isRead ? AppColors.secondaryText : AppColors.primaryText)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)

            if !ranked.item.summary.isEmpty {
                Text(ranked.item.summary)
                    .font(.subheadline)
                    .foregroundStyle(AppColors.secondaryText)
                    .lineLimit(3)
            }

            HStack(spacing: 6) {
                Text(sourceTitle)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(AppColors.brand)
                Text("·")
                    .font(.caption)
                    .foregroundStyle(AppColors.tertiaryText)
                Text(DateFormatting.relativeText(from: ranked.item.publishedAt))
                    .font(.caption)
                    .foregroundStyle(AppColors.tertiaryText)
                Spacer()
            }
        }
        .padding(AppSpacing.cardInner)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cornerRadius, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: AppSpacing.shadowRadius, x: 0, y: 3)
        .padding(.horizontal, AppSpacing.screenHorizontal)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var cover: some View {
        if let imageURL = ranked.item.imageURL {
            AsyncImage(url: imageURL) { phase in
                switch phase {
                case .empty:
                    coverPlaceholder
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 180)
                        .clipped()
                case .failure:
                    coverPlaceholder
                @unknown default:
                    coverPlaceholder
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 180)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private var coverPlaceholder: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(AppColors.screenBackground)
            .frame(height: 180)
            .overlay {
                Image(systemName: "photo")
                    .font(.title3)
                    .foregroundStyle(AppColors.tertiaryText)
            }
    }
}

#Preview {
    let source = FeedSource(title: "TechPulse", url: URL(string: "https://example.com")!)
    let item = FeedItem(
        id: "preview",
        sourceID: source.id,
        title: "纯 SwiftUI 构建的极简 RSS 阅读器 Milla 正式开源",
        link: nil,
        summary: "上下滑动浏览卡片，多订阅源交替排序，支持每日更新数、质量权重与抽样配置。",
        contentHTML: "",
        imageURL: URL(string: "https://example.com/cover.jpg"),
        author: nil,
        publishedAt: Date().addingTimeInterval(-1_800)
    )
    let ranked = RankedFeedItem(
        item: item, sourceID: source.id,
        qualityScore: 0.9, recencyScore: 0.95, score: 0.92
    )
    return ScrollView {
        VStack(spacing: 16) {
            FeedCardView(ranked: ranked, sourceTitle: "TechPulse", isRead: false)
            FeedCardView(ranked: ranked, sourceTitle: "TechPulse", isRead: true)
        }
        .padding(.vertical)
    }
    .background(AppColors.screenBackground)
}
