import SwiftUI
import MillaCore

struct RootView: View {

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
