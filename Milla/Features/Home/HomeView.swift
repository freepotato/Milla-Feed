import SwiftUI
import MillaCore

/// 首页信息流。
struct HomeView: View {

    @Environment(FeedRepository.self) private var repository
    @Environment(AppSettings.self) private var settings
    @Environment(AppRouter.self) private var router

    @State private var viewModel = HomeViewModel()
    @State private var didInitialLoad = false
    @State private var showsDailyNews = false

    var body: some View {
        // 每日新闻模式下不挂下拉刷新（它有自己"当天已抓不再抓"的节奏）；
        // 同时从左边缘右滑可直接退回信息流（该页不在导航栈里，系统返回手势够不到）
        Group {
            if showsDailyNews {
                scrollContent
                    .simultaneousGesture(backToFeedGesture)
            } else {
                scrollContent
                    .refreshable {
                        await viewModel.load(
                            repository: repository,
                            settings: settings,
                            refreshNetwork: true
                        )
                    }
            }
        }
        .background(AppColors.screenBackground)
        .millaAdaptiveChrome()
        .toolbar(.hidden, for: .navigationBar)
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

    private var scrollContent: some View {
        ScrollView {
            LazyVStack(spacing: AppSpacing.stackVertical) {
                TopBannerView(
                    isDailyNews: showsDailyNews,
                    onTapLogo: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showsDailyNews.toggle()
                        }
                    },
                    onTapSettings: {
                        router.path.append(Route.settings)
                    }
                )

                if showsDailyNews {
                    DailyNewsView()
                } else {
                    feedContent
                }
            }
            .padding(.bottom, 24)
        }
    }

    /// 左边缘右滑退回信息流：要求起点靠近屏幕左缘、横向为主、距离足够，
    /// 避免与纵向滚动冲突（simultaneousGesture 不拦截滚动）。
    private var backToFeedGesture: some Gesture {
        DragGesture(minimumDistance: 20, coordinateSpace: .local)
            .onEnded { value in
                let fromLeftEdge = value.startLocation.x < 40
                let rightward = value.translation.width > 80
                let horizontal = abs(value.translation.width) > abs(value.translation.height) * 1.5
                if fromLeftEdge && rightward && horizontal {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showsDailyNews = false
                    }
                }
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
            ) {
                // 无内容
            }
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

#Preview("首页") {
    RootView()
        .environment(AppSettings())
        .environment(try! FeedRepository(inMemory: true))
        .environment(AppRouter())
}
