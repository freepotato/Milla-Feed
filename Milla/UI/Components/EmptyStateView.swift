import SwiftUI

/// 空状态 / 错误占位组件。
struct EmptyStateView: View {

    let systemImage: String
    let title: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(AppColors.tertiaryText)
                .padding(.bottom, 4)

            Text(title)
                .font(.headline)
                .foregroundStyle(AppColors.primaryText)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(AppColors.secondaryText)
                .multilineTextAlignment(.center)

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
                    .padding(.top, 8)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    EmptyStateView(
        systemImage: "tray",
        title: "还没有内容",
        message: "下拉刷新，或在设置中添加订阅源。",
        actionTitle: "刷新"
    ) {
        // 预览占位
    }
}
