import SwiftUI

/// iOS 27 / Liquid Glass 适配的唯一收口位置。
///
/// 设计原则：
/// 1. 当前所有 UI 仅使用 iOS 18 SDK 即存在的原生 SwiftUI 组件，
///    用 Xcode 27 + iOS 27 SDK 编译时，系统会自动让这些组件获得 Liquid Glass 外观，
///    不需要（也不应该）手写模拟玻璃材质；
/// 2. 未来要使用 iOS 27.1 的 Reserved Region、Arrangement View 等新 API 时，
///    只能在本文件中按下述模板接入，避免污染业务视图：
///
///    ```swift
///    #if compiler(>= 6.3)   // 仅 Xcode 27 工具链可见新符号
///    if #available(iOS 27.1, *) {
///        // 调用 iOS 27.1 专属 API
///    } else {
///        // 降级路径：回退到 iOS 18 通用布局
///    }
///    #endif
///    ```
///
///    注意：直接写死 iOS 27 的符号会导致用 Xcode 26（App Store 合规构建）编译失败，
///    因此新符号必须同时被 `#if compiler` 与 `if #available` 双重保护。
enum PlatformFeatures {

    /// 当前运行环境的主系统版本（仅供日志与调试展示）。
    static var majorVersion: Int {
        ProcessInfo.processInfo.operatingSystemVersion.majorVersion
    }
}

extension View {

    /// 所有 iOS 27 专属外观增强都挂载在这里。
    /// 当前为空操作：保持原生组件行为，由系统按编译 SDK 自动适配外观。
    func millaAdaptiveChrome() -> some View {
        self
    }
}
