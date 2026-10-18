import SwiftUI
import MillaCore

/// 每日新闻页：热摸爽「今日大事」，默认 Top 10，可切换分类板块。
/// 点击左上角 Milla logo 进入/退出（由 HomeView 切换）。
struct DailyNewsView: View {

    @State private var viewModel = DailyNewsViewModel()
    @State private var didLoad = false
    @State private var selectedEvent: RemoShuangToday.Event?

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.stackVertical) {
            header

            if viewModel.isGenerating {
                generatingBlock
            } else if let message = viewModel.emptyMessage, viewModel.events.isEmpty {
                EmptyStateView(
                    systemImage: "newspaper",
                    title: "暂时没有每日新闻",
                    message: message
                ) {}
            } else {
                categoryChips
                entriesBlock
            }
        }
        .task {
            guard !didLoad else { return }
            didLoad = true
            await viewModel.loadIfNeeded()
        }
        .sheet(item: $selectedEvent) { event in
            if let url = event.eventURL {
                SafariView(url: url)
            }
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
            if let fetchedAt = viewModel.fetchedAt {
                Text(DateFormatting.relativeText(from: fetchedAt) + "更新")
                    .font(.caption)
                    .foregroundStyle(AppColors.tertiaryText)
            }
        }
        .padding(.horizontal, AppSpacing.screenHorizontal)
    }

    private var generatingBlock: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("正在抓取今日大事…")
                .font(.subheadline)
                .foregroundStyle(AppColors.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(viewModel.categories) { category in
                    let isSelected = category.key == viewModel.selectedCategoryKey
                    Button {
                        viewModel.selectCategory(category.key)
                    } label: {
                        Text(category.label)
                            .font(.subheadline.weight(isSelected ? .semibold : .regular))
                            .foregroundStyle(isSelected ? Color.white : AppColors.primaryText)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(
                                Capsule().fill(
                                    isSelected ? AppColors.brand : AppColors.cardBackground
                                )
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("分类：\(category.label)")
                }
            }
            .padding(.horizontal, AppSpacing.screenHorizontal)
        }
    }

    private var entriesBlock: some View {
        ForEach(Array(viewModel.events.enumerated()), id: \.element.id) { index, event in
            Button {
                selectedEvent = event
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
                        Text(event.title)
                            .font(.body)
                            .foregroundStyle(AppColors.primaryText)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                        HStack(spacing: 6) {
                            Text("\(event.sourceCount) 家报道")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(AppColors.brand)
                            Text("·")
                                .font(.caption)
                                .foregroundStyle(AppColors.tertiaryText)
                            Text(event.category)
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
            .accessibilityLabel("第 \(index + 1) 条：\(event.title)")
        }
    }
}
