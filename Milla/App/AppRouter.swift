import Foundation
import Observation
import SwiftUI
import MillaCore

/// 全局导航路由。统一使用 NavigationStack 的 path 驱动，
/// 天然适配 iPad 分栏、iPhone Duo / 折叠屏等不同 Size Class。
@Observable
final class AppRouter {
    var path: [Route] = []
}

enum Route: Hashable {
    case settings
    case article(RankedFeedItem)
    case favorites
}
