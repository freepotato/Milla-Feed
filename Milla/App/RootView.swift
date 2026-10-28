import SwiftUI
import MillaCore

/// 应用根视图：底部 Tab 栏切换「信息流」与「新闻」。
struct RootView: View {

    @State private var selection = 0

    var body: some View {
        TabView(selection: $selection) {
            FeedTab()
                .tabItem {
                    Label("信息流", systemImage: "list.bullet.rectangle")
                }
                .tag(0)

            // 传入激活状态：Tab 常驻内存，靠它感知"切回新闻页"，逐次检查小时规则
            NewsTab(isActive: selection == 1)
                .tabItem {
                    Label("新闻", systemImage: "newspaper.fill")
                }
                .tag(1)
        }
        .tint(AppColors.brand)
    }
}

/// 信息流 Tab：NavigationStack 承载设置与文章详情。
struct FeedTab: View {

    @Environment(AppRouter.self) private var router

    var body: some View {
        @Bindable var router = router
        NavigationStack(path: $router.path) {
            HomeView()
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case .settings:
                        SettingsView()
                    case .article(let ranked):
                        ArticleView(ranked: ranked)
                    }
                }
        }
    }
}

/// 新闻 Tab：承载每日新闻页，设置走本 Tab 内的导航栈。
struct NewsTab: View {

    let isActive: Bool

    @State private var path: [Route] = []

    var body: some View {
        NavigationStack(path: $path) {
            DailyNewsView(isActive: isActive) {
                path.append(Route.settings)
            }
            .navigationDestination(for: Route.self) { route in
                if case .settings = route {
                    SettingsView()
                }
            }
        }
    }
}
