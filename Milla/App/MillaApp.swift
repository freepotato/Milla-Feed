import SwiftUI
import SwiftData

@main
struct MillaApp: App {

    let container: ModelContainer

    @State private var settings: AppSettings
    @State private var repository: FeedRepository
    @State private var router = AppRouter()

    init() {
        do {
            let schema = Schema([StoredFeedSource.self, StoredFeedArticle.self])
            let configuration = ModelConfiguration(schema: schema)
            let container = try ModelContainer(for: schema, configurations: [configuration])
            self.container = container
            _settings = State(initialValue: AppSettings())
            let repository = FeedRepository(container: container)
            repository.seedInitialSourcesIfNeeded(DefaultFeeds.sources)
            _repository = State(initialValue: repository)
        } catch {
            fatalError("无法初始化 SwiftData：\(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .modelContainer(container)
                .environment(settings)
                .environment(repository)
                .environment(router)
                .preferredColorScheme(settings.appearanceMode.colorScheme)
        }
    }
}
