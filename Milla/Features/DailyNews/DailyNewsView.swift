import SwiftUI
import UIKit
import MillaCore

/// 每日新闻页：热摸爽首页榜单（综合 = 头条下方从 1 开始的完整列表），
/// 「正在升温」只在综合页展示；每次打开都在后台刷新，先展示缓存。
struct DailyNewsView: View {

    /// 新闻 Tab 当前是否被选中（Tab 常驻内存，靠它感知重新打开）。
    let isActive: Bool
    let onTapSettings: () -> Void

    @Environment(\.scenePhase) private var scenePhase

    @State private var viewModel = DailyNewsViewModel()
    @State private var selectedLink: SafariLink?
    @State private var hasLoaded = false

    var body: some View {
        @Bindable var viewModel = viewModel
        VStack(spacing: 0) {
            header
            categoryChips

            if viewModel.categories.isEmpty, viewModel.isRefreshing {
                generatingBlock
            } else if viewModel.categories.isEmpty, let message = viewModel.emptyMessage {
                EmptyStateView(
                    systemImage: "newspaper",
                    title: "暂时没有每日新闻",
                    message: message
                ) {}
            } else {
                pagedCategories
                    .animation(.easeInOut(duration: 0.28), value: viewModel.dataVersion)
            }
        }
        .background(AppColors.screenBackground)
        .task {
            // 首次进入：先展示缓存，再后台刷新
            await viewModel.load()
            hasLoaded = true
        }
        .onChange(of: isActive) { _, active in
            guard active else { return }
            Task { await viewModel.refresh() }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active, isActive else { return }
            Task { await viewModel.refresh() }
        }
        .onAppear {
            // 从本 Tab 内的设置页 / 文章返回时也刷新
            guard hasLoaded else { return }
            Task { await viewModel.refresh() }
        }
        .sheet(item: $selectedLink) { link in
            SafariView(url: link.url)
        }
    }

    // MARK: - Subviews

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("每日新闻")
                .font(.title3.weight(.bold))
                .foregroundStyle(AppColors.primaryText)
            Spacer()
            if viewModel.isRefreshing {
                ProgressView()
                    .controlSize(.small)
                    .padding(.trailing, 2)
            } else if let fetchedAt = viewModel.fetchedAt {
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
                    rising: category.key == DailyNewsViewModel.combinedKey
                        ? viewModel.rising
                        : [],
                    onSelect: { url in selectedLink = SafariLink(url: url) }
                )
                .tag(category.key)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
    }
}

// MARK: - Safari 链接

private struct SafariLink: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}

// MARK: - 单分类条目页

private struct CategoryEntriesPage: View {

    let events: [RemoShuangRanked.Entry]
    let rising: [RemoShuangRanked.Rising]
    let onSelect: (URL) -> Void

    var body: some View {
        ScrollView {
            LazyVStack(spacing: AppSpacing.stackVertical) {
                if !rising.isEmpty {
                    risingCard
                }
                ForEach(Array(events.enumerated()), id: \.element.id) { index, event in
                    eventRow(event, index: index)
                }
            }
            .padding(.bottom, 24)
        }
    }

    // MARK: 正在升温

    private var risingCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "flame.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
                Text("正在升温")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColors.primaryText)
                Spacer()
                Text("\(rising.count) 条")
                    .font(.caption2)
                    .foregroundStyle(AppColors.tertiaryText)
            }
            .padding(.horizontal, AppSpacing.cardInner)
            .padding(.top, 14)
            .padding(.bottom, 10)

            ForEach(Array(rising.enumerated()), id: \.element.id) { index, item in
                if index > 0 {
                    Divider()
                        .padding(.leading, AppSpacing.cardInner + 20)
                }
                Button {
                    if let url = item.link { onSelect(url) }
                } label: {
                    risingRow(item, index: index)
                }
                .buttonStyle(.plain)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: AppSpacing.cornerRadius, style: .continuous)
                .fill(AppColors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: AppSpacing.cornerRadius, style: .continuous)
                        .fill(Color.orange.opacity(0.07))
                )
        )
        .padding(.horizontal, AppSpacing.screenHorizontal)
    }

    private func risingRow(_ item: RemoShuangRanked.Rising, index: Int) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(index + 1)")
                .font(.caption.weight(.bold))
                .foregroundStyle(.orange)
                .frame(width: 20)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 5) {
                Text(item.title)
                    .font(.body)
                    .foregroundStyle(AppColors.primaryText)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .contextMenu {
                        Button("复制标题", systemImage: "doc.on.doc") {
                            UIPasteboard.general.string = item.title
                        }
                    }

                HStack(spacing: 8) {
                    Text("↑ \(item.risePercent)%")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.orange)
                    Text("\(item.sourceCount) 来源")
                        .font(.caption)
                        .foregroundStyle(AppColors.tertiaryText)
                    if item.newSources > 0 {
                        Text("新增 \(item.newSources) 个")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                    if let date = item.firstSeenDate {
                        Text(DateFormatting.relativeText(from: date) + "首次出现")
                            .font(.caption)
                            .foregroundStyle(AppColors.tertiaryText)
                    }
                    Spacer(minLength: 0)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, AppSpacing.cardInner)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityLabel("正在升温：\(item.title)")
    }

    // MARK: 榜单条目

    private func eventRow(_ event: RemoShuangRanked.Entry, index: Int) -> some View {
        Button {
            if let url = event.link { onSelect(url) }
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
                        Text(sourceText(event))
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

    /// "东方财富 等 6 个来源"
    private func sourceText(_ event: RemoShuangRanked.Entry) -> String {
        event.sourceCount > 1
            ? "\(event.sourceName) 等 \(event.sourceCount) 个来源"
            : event.sourceName
    }
}
