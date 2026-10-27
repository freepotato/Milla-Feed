import SwiftUI
import UIKit
import MillaCore

/// 每日新闻页：热摸爽主页热榜，默认综合，可左右滑动切换大类；每小时抓取一次。
struct DailyNewsView: View {

    let onTapSettings: () -> Void

    @State private var viewModel = DailyNewsViewModel()
    @State private var didLoad = false
    @State private var selectedEvent: RemoShuangHot.Entry?

    var body: some View {
        @Bindable var viewModel = viewModel
        VStack(spacing: 0) {
            header
            categoryChips

            if viewModel.isGenerating {
                generatingBlock
            } else if viewModel.categories.isEmpty, let message = viewModel.emptyMessage {
                EmptyStateView(
                    systemImage: "newspaper",
                    title: "暂时没有每日新闻",
                    message: message
                ) {}
            } else {
                pagedCategories
            }
        }
        .background(AppColors.screenBackground)
        .task {
            guard !didLoad else { return }
            didLoad = true
            await viewModel.loadIfNeeded()
        }
        .sheet(item: $selectedEvent) { event in
            if let url = event.link {
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
                    .padding(.trailing, 4)
            }
            Button(action: onTapSettings) {
                Image(systemName: "gearshape")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AppColors.primaryText)
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("设置")
        }
        .padding(.horizontal, AppSpacing.screenHorizontal)
        .padding(.top, AppSpacing.bannerTop)
        .padding(.bottom, AppSpacing.bannerBottom)
    }

    private var generatingBlock: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("正在抓取热榜…")
                .font(.subheadline)
                .foregroundStyle(AppColors.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        .padding(.bottom, 8)
    }

    /// 分类分页：每个分类一页，左右滑动切换（iOS 原生分页拖动感）。
    private var pagedCategories: some View {
        TabView(selection: $viewModel.selectedCategoryKey) {
            ForEach(viewModel.categories) { category in
                CategoryEntriesPage(
                    events: viewModel.events(for: category.key),
                    onSelect: { selectedEvent = $0 }
                )
                .tag(category.key)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .onChange(of: viewModel.selectedCategoryKey) { _, _ in
            viewModel.applySelection()
        }
    }
}

// MARK: - 单分类条目页

private struct CategoryEntriesPage: View {

    let events: [RemoShuangHot.Entry]
    let onSelect: (RemoShuangHot.Entry) -> Void

    var body: some View {
        ScrollView {
            LazyVStack(spacing: AppSpacing.stackVertical) {
                ForEach(Array(events.enumerated()), id: \.element.id) { index, event in
                    eventRow(event, index: index)
                }
            }
            .padding(.bottom, 24)
        }
    }

    private func eventRow(_ event: RemoShuangHot.Entry, index: Int) -> some View {
        Button {
            onSelect(event)
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
                        .contextMenu {
                            Button("复制标题", systemImage: "doc.on.doc") {
                                UIPasteboard.general.string = event.title
                            }
                        }
                    HStack(spacing: 6) {
                        Text(event.sourceName)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(AppColors.brand)
                        if !event.heat.isEmpty {
                            Text("·")
                                .font(.caption)
                                .foregroundStyle(AppColors.tertiaryText)
                            Text(event.heat)
                                .font(.caption)
                                .foregroundStyle(AppColors.tertiaryText)
                        }
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
