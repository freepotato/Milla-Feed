import SwiftUI

/// 首页信息流。
struct HomeView: View {

    @Environment(FeedRepository.self) private var repository
    @Environment(AppSettings.self) private var settings
    @Environment(AppRouter.self) private var router

    @State private var viewModel = HomeViewModel()
    @State private var didInitialLoad = false

    var body: some View {
        ScrollView {
            LazyVStack(spacing: AppSpacing.stackVertical) {
                TopBannerView(onTapSettings: {
                    router.path.append(Route.settings)
                })

                feedContent
            }
            .padding(.bottom, 24)
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
    NavigationStack {
        HomeView()
    }
    .environment(AppSettings())
    .environment(try! FeedRepository(inMemory: true))
    .environment(AppRouter())
}
