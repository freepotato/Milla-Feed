import SwiftUI

/// 首页信息流。
struct HomeView: View {

    @Environment(FeedRepository.self) private var repository
    @Environment(AppSettings.self) private var settings
    @Environment(AppRouter.self) private var router

    @State private var viewModel = HomeViewModel()
    @State private var didInitialLoad = false
    @State private var searchText = ""

    // 可拖动的右侧滚动条（系统滚动指示器只能看不能按）
    @State private var scrollPosition = ScrollPosition(edge: .top)
    @State private var scrollMetrics = ScrollMetrics()
    @State private var isDraggingScrollBar = false

    /// 正在搜索：展示结果列表，替换信息流。
    private var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: AppSpacing.stackVertical) {
                TopBannerView(
                    searchText: $searchText,
                    onTapFavorites: { router.path.append(.favorites) },
                    onTapSettings: { router.path.append(Route.settings) }
                )

                if isSearching {
                    searchResultsBlock
                } else {
                    feedContent
                }
            }
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .scrollPosition($scrollPosition)
        .onScrollGeometryChange(for: ScrollMetrics.self) { geometry in
            ScrollMetrics(
                offsetY: max(0, geometry.contentOffset.y + geometry.contentInsets.top),
                contentHeight: geometry.contentSize.height,
                visibleHeight: geometry.containerSize.height
            )
        } action: { _, newValue in
            scrollMetrics = newValue
        }
        .overlay(alignment: .trailing) {
            draggableScrollBar
        }
        .background(AppColors.screenBackground)
        .millaAdaptiveChrome()
        .toolbar(.hidden, for: .navigationBar)
        .refreshable {
            await viewModel.load(
                repository: repository,
                settings: settings,
                refreshNetwork: true
            )
        }
        .task {
            guard !didInitialLoad else { return }
            didInitialLoad = true
            await viewModel.load(
                repository: repository,
                settings: settings,
                refreshNetwork: settings.refreshOnLaunch
            )
        }
        .onAppear {
            // 从详情页返回时同步已读态，不触发网络请求
            if didInitialLoad {
                viewModel.rebuild(repository: repository, settings: settings)
            }
        }
    }

    // MARK: - 可拖动滚动条

    /// 覆盖在 ScrollView 右侧的滚动条：按住拖动可直接跳到任意位置。
    @ViewBuilder
    private var draggableScrollBar: some View {
        let maxOffset = max(1, scrollMetrics.contentHeight - scrollMetrics.visibleHeight)
        if scrollMetrics.contentHeight > scrollMetrics.visibleHeight + 60 {
            GeometryReader { proxy in
                let trackInset: CGFloat = 8
                let trackHeight = max(1, proxy.size.height - trackInset * 2)
                let thumbHeight = min(
                    trackHeight,
                    max(48, trackHeight * scrollMetrics.visibleHeight / scrollMetrics.contentHeight)
                )
                let travel = max(1, trackHeight - thumbHeight)
                let progress = min(1, max(0, scrollMetrics.offsetY / maxOffset))

                ZStack(alignment: .top) {
                    Color.clear
                    Capsule()
                        .fill(Color.primary.opacity(isDraggingScrollBar ? 0.5 : 0.2))
                        .frame(
                            width: isDraggingScrollBar ? 6 : 4,
                            height: thumbHeight
                        )
                        .offset(y: travel * progress)
                }
                .frame(width: 24, height: trackHeight)
                .contentShape(Rectangle())
                .highPriorityGesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            // 按住即把滑块中心对到手指位置，拖动时按位置映射滚动
                            if !isDraggingScrollBar { isDraggingScrollBar = true }
                            let thumbTop = value.location.y - thumbHeight / 2
                            let dragProgress = min(1, max(0, thumbTop / travel))
                            scrollPosition.scrollTo(y: dragProgress * maxOffset)
                        }
                        .onEnded { _ in
                            isDraggingScrollBar = false
                        }
                )
                .offset(y: trackInset)
                .accessibilityHidden(true)
            }
            .frame(width: 24)
        }
    }

    @ViewBuilder
    private var feedContent: some View {
        switch viewModel.state {
        case .initial, .loading:
            loadingBlock
        case .loaded:
            cardsBlock
            if let message = viewModel.failureMessage {
                failureBanner(message)
            }
        case .empty(let message):
            EmptyStateView(
                systemImage: "tray",
                title: "没有可展示的内容",
                message: message
            ) {}
        case .error(let message):
            EmptyStateView(
                systemImage: "wifi.exclamationmark",
                title: "加载失败",
                message: message,
                actionTitle: "重试"
            ) {
                Task {
                    await viewModel.load(
                        repository: repository,
                        settings: settings,
                        refreshNetwork: true
                    )
                }
            }
        }
    }

    // MARK: - Subviews

    private var searchResultsBlock: some View {
        let results = viewModel.search(searchText, repository: repository)
        return Group {
            if results.isEmpty {
                EmptyStateView(
                    systemImage: "magnifyingglass",
                    title: "没有找到相关文章",
                    message: "换个关键词试试。"
                ) {}
                .padding(.top, 60)
            } else {
                ForEach(results) { ranked in
                    Button {
                        router.path.append(Route.article(ranked))
                    } label: {
                        FeedCardView(
                            ranked: ranked,
                            sourceTitle: viewModel.sourceTitles[ranked.sourceID] ?? "未知来源",
                            isRead: viewModel.readIDs.contains(ranked.id)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var loadingBlock: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("正在更新订阅源…")
                .font(.subheadline)
                .foregroundStyle(AppColors.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }

    private var cardsBlock: some View {
        ForEach(viewModel.rankedItems) { ranked in
            Button {
                router.path.append(Route.article(ranked))
            } label: {
                FeedCardView(
                    ranked: ranked,
                    sourceTitle: viewModel.sourceTitles[ranked.sourceID] ?? "未知来源",
                    isRead: viewModel.readIDs.contains(ranked.id)
                )
            }
            .buttonStyle(.plain)
        }
    }

    private func failureBanner(_ message: String) -> some View {
        Text(message)
            .font(.caption)
            .foregroundStyle(AppColors.secondaryText)
            .padding(.horizontal, AppSpacing.screenHorizontal)
            .padding(.vertical, 8)
            .background(AppColors.cardBackground)
            .clipShape(Capsule())
            .padding(.horizontal, AppSpacing.screenHorizontal)
    }
}

/// 滚动几何快照：驱动自定义滚动条的位置与高度。
private struct ScrollMetrics: Equatable {
    var offsetY: CGFloat = 0
    var contentHeight: CGFloat = 0
    var visibleHeight: CGFloat = 0
}

#Preview("首页") {
    NavigationStack {
        HomeView()
    }
    .environment(AppSettings())
    .environment(try! FeedRepository(inMemory: true))
    .environment(AppRouter())
}
