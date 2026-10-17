import Foundation
import SwiftUI
import Observation
import MillaCore

/// 全局设置，持久化在 UserDefaults。
/// SwiftData 负责文章/订阅源数据，权重等轻量配置走 UserDefaults。
@Observable
final class AppSettings {

    // MARK: 排序权重（默认 quality 0.6 / recency 0.4）
    var qualityWeight: Double {
        didSet { defaults.set(qualityWeight, forKey: Keys.qualityWeight) }
    }
    var recencyWeight: Double {
        didSet { defaults.set(recencyWeight, forKey: Keys.recencyWeight) }
    }
    var recencyHalfLifeHours: Double {
        didSet { defaults.set(recencyHalfLifeHours, forKey: Keys.halfLife) }
    }
    var stochasticSampling: Bool {
        didSet { defaults.set(stochasticSampling, forKey: Keys.stochastic) }
    }

    // MARK: 新订阅源默认参数
    var defaultDailyLimit: Int {
        didSet { defaults.set(defaultDailyLimit, forKey: Keys.defaultDailyLimit) }
    }
    var defaultSampleSize: Int {
        didSet { defaults.set(defaultSampleSize, forKey: Keys.defaultSampleSize) }
    }
    var defaultQualityScore: Double {
        didSet { defaults.set(defaultQualityScore, forKey: Keys.defaultQualityScore) }
    }

    // MARK: 外观
    var appearanceMode: AppearanceMode {
        didSet { defaults.set(appearanceMode.rawValue, forKey: Keys.appearanceMode) }
    }

    // MARK: 其他
    var refreshOnLaunch: Bool {
        didSet { defaults.set(refreshOnLaunch, forKey: Keys.refreshOnLaunch) }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.qualityWeight = defaults.object(forKey: Keys.qualityWeight) as? Double ?? 0.6
        self.recencyWeight = defaults.object(forKey: Keys.recencyWeight) as? Double ?? 0.4
        self.recencyHalfLifeHours = defaults.object(forKey: Keys.halfLife) as? Double ?? 24
        self.stochasticSampling = defaults.object(forKey: Keys.stochastic) as? Bool ?? false
        self.defaultDailyLimit = defaults.object(forKey: Keys.defaultDailyLimit) as? Int ?? 10
        self.defaultSampleSize = defaults.object(forKey: Keys.defaultSampleSize) as? Int ?? 2
        self.defaultQualityScore = defaults.object(forKey: Keys.defaultQualityScore) as? Double ?? 0.8
        self.appearanceMode = AppearanceMode(
            rawValue: defaults.string(forKey: Keys.appearanceMode) ?? ""
        ) ?? .system
        self.refreshOnLaunch = defaults.object(forKey: Keys.refreshOnLaunch) as? Bool ?? true
    }

    func makeRankingConfiguration() -> RankingConfiguration {
        RankingConfiguration(
            qualityWeight: qualityWeight,
            recencyWeight: recencyWeight,
            recencyHalfLifeHours: recencyHalfLifeHours,
            stochasticSampling: stochasticSampling
        )
    }

    private enum Keys {
        static let qualityWeight = "ranking.qualityWeight"
        static let recencyWeight = "ranking.recencyWeight"
        static let halfLife = "ranking.halfLifeHours"
        static let stochastic = "ranking.stochasticSampling"
        static let defaultDailyLimit = "feeds.defaultDailyLimit"
        static let defaultSampleSize = "feeds.defaultSampleSize"
        static let defaultQualityScore = "feeds.defaultQualityScore"
        static let appearanceMode = "appearance.mode"
        static let refreshOnLaunch = "feeds.refreshOnLaunch"
    }
}

/// 界面外观模式：跟随系统 / 浅色 / 深色。
enum AppearanceMode: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return "跟随系统"
        case .light: return "浅色"
        case .dark: return "深色"
        }
    }

    /// 传给 .preferredColorScheme 的值；跟随系统时为 nil。
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}
