import SwiftUI
import MillaCore

/// 每日新闻页：每天上午/午后各生成一次的 10 条时效性新闻速览。
/// 点击左上角 Milla logo 进入/退出（由 HomeView 切换）。
struct DailyNewsView: View {

    @Environment(FeedRepository.self) private var repository
    @Environment(AppSettings.self) private var settings
    @Environment(AppRouter.self) private var router

    @State private var viewModel = DailyNewsViewModel()
    @State private var didLoad = false

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.stackVertical) {
            header

            if viewModel.isGenerating {
                generatingBlock
            } else if let message = viewModel.emptyMessage, viewModel.entries.isEmpty {
                EmptyStateView(
                    systemImage: "newspaper",
                    title: "暂时没有每日新闻",
                    message: message
                ) {}
            } else {
                entriesBlock
            }
        }
        .task {
            guard !didLoad else { return }
            didLoad = true
            await viewModel.loadIfNeeded(repository: repository, settings: settings)
        }
    }

    // MARK: - Subviews

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("每日新闻")
                .font(.title3.weight(.bold))
                .foregroundStyle(AppColors.primaryText)
            if !viewModel.slotName.isEmpty {
                Text(viewModel.slotName)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(AppColors.brand)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(AppColors.brand.opacity(0.12))
                    .clipShape(Capsule())
            }
            Spacer()
            if let generatedAt = viewModel.generatedAt {
                Text(DateFormatting.relativeText(from: generatedAt) + "更新")
                    .font(.caption)
                    .foregroundStyle(AppColors.tertiaryText)
            }
        }
        .padding(.horizontal, AppSpacing.screenHorizontal)
    }

    private var generatingBlock: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("正在抓取 24 小时内的新闻…")
                .font(.subheadline)
                .foregroundStyle(AppColors.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    private var entriesBlock: some View {
        ForEach(Array(viewModel.entries.enumerated()), id: \.element.id) { index, entry in
            Button {
                router.path.append(
                    Route.article(
                        RankedFeedItem(
                            item: entry.item,
                            sourceID: entry.item.sourceID,
                            qualityScore: 0,
                            recencyScore: 0,
                            score: 0
                        )
                    )
                )
            } label: {
                HStack(alignment: .top, spacing: 12) {
                    Text("\(index + 1)")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(index < 3 ? Color.white : AppColors.secondaryText)
                        .frame(width: 26, height: 26)
                        .background(
                            Circle().fill(
                                index < 3 ? AppColors.brand : AppColors.screenBackground
                            )
                        )
                        .padding(.top, 1)

                    VStack(alignment: .leading, spacing: 5) {
                        Text(entry.headline)
                            .font(.body)
                            .foregroundStyle(AppColors.primaryText)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                        HStack(spacing: 6) {
                            Text(entry.sourceTitle)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(AppColors.brand)
                            Text("·")
                                .font(.caption)
                                .foregroundStyle(AppColors.tertiaryText)
                            Text(DateFormatting.relativeText(from: entry.publishedAt))
                                .font(.caption)
                                .foregroundStyle(AppColors.tertiaryText)
                            Spacer()
                        }
                    }
                    Spacer(minLength: 0)
                }
                .padding(AppSpacing.cardInner)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppColors.cardBackground)
                .clipShape(
                    RoundedRectangle(cornerRadius: AppSpacing.cornerRadius, style: .continuous)
                )
                .shadow(color: .black.opacity(0.06), radius: AppSpacing.shadowRadius, x: 0, y: 3)
                .padding(.horizontal, AppSpacing.screenHorizontal)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("第 \(index + 1) 条：\(entry.headline)")
        }
    }
}
