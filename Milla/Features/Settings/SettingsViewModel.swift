import Foundation
import Observation
import SwiftData

/// 设置页状态：订阅源增删启停与参数编辑。
@MainActor
@Observable
final class SettingsViewModel {

    private(set) var sources: [StoredFeedSource] = []
    var isPresentingAddSheet = false
    var draftTitle = ""
    var draftURL = ""
    var errorText: String?
    var showsError = false

    func load(repository: FeedRepository) {
        sources = repository.allStoredSources()
    }

    func addDraft(repository: FeedRepository, settings: AppSettings) {
        do {
            let stored = try repository.addSource(
                title: draftTitle,
                urlString: draftURL,
                dailyLimit: settings.defaultDailyLimit,
                sampleSize: settings.defaultSampleSize,
                qualityScore: settings.defaultQualityScore
            )
            sources = repository.allStoredSources()
            draftTitle = ""
            draftURL = ""
            isPresentingAddSheet = false
            // 新增后立即尝试拉取一次
            Task {
                let syncService = FeedSyncService()
                _ = await syncService.sync(sources: [stored], repository: repository)
                sources = repository.allStoredSources()
            }
        } catch {
            errorText = error.localizedDescription
            showsError = true
        }
    }

    func delete(at offsets: IndexSet, repository: FeedRepository) {
        for index in offsets {
            repository.deleteSource(sources[index])
        }
        sources = repository.allStoredSources()
    }

    func delete(_ source: StoredFeedSource, repository: FeedRepository) {
        repository.deleteSource(source)
        sources = repository.allStoredSources()
    }

    func persist(_ repository: FeedRepository) {
        // 参数改动都直接作用于 @Model 对象，保存由仓储负责
        repository.persistPendingChanges()
        sources = repository.allStoredSources()
    }
}
