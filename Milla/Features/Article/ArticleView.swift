import SwiftUI
import MillaCore

/// 文章详情页：标题、来源、时间、正文、打开原文、收藏。
struct ArticleView: View {

    let ranked: RankedFeedItem

    @Environment(FeedRepository.self) private var repository
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: ArticleViewModel
    @State private var showsSafari = false
    @State private var bodyLink: URL?

    init(ranked: RankedFeedItem) {
        self.ranked = ranked
        _viewModel = State(initialValue: ArticleViewModel(ranked: ranked))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(ranked.item.title)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(AppColors.primaryText)
                    .fixedSize(horizontal: false, vertical: true)

                metaRow

                if let imageURL = ranked.item.imageURL {
                    CoverImageView(url: imageURL) { image in
                        // 封面按横向宽度自适应完整展示（不裁切不压扁）；
                        // 超高竖图按 480pt 高度兜底整体缩小
                        image
                            .scaledToFit()
                            .frame(maxWidth: .infinity, maxHeight: 480)
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(AppColors.screenBackground)
                            .frame(height: 160)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                Divider()

                if hasBody {
                    // 正文与封面同图的 <img> 只保留封面一处，避免同图重复
                    HTMLTextView(
                        html: ContentSanitizer.removingImage(
                            from: ranked.item.contentHTML,
                            matching: ranked.item.imageURL
                        ),
                        onOpenLink: { bodyLink = $0 }
                    )
                } else if !ranked.item.summary.isEmpty {
                    Text(ranked.item.summary)
                        .font(.body)
                        .foregroundStyle(AppColors.primaryText)
                } else {
                    Text("该订阅源未提供正文摘要，可直接打开原文阅读。")
                        .font(.body)
                        .foregroundStyle(AppColors.secondaryText)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(AppColors.screenBackground)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    viewModel.toggleFavorite(repository: repository)
                } label: {
                    Image(systemName: viewModel.isFavorite ? "star.fill" : "star")
                        .foregroundStyle(viewModel.isFavorite ? .yellow : AppColors.primaryText)
                }
                .accessibilityLabel(viewModel.isFavorite ? "取消收藏" : "收藏")
            }

            if ranked.item.link != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showsSafari = true
                    } label: {
                        Image(systemName: "safari")
                    }
                    .accessibilityLabel("打开原文")
                }
            }
        }
        .sheet(isPresented: $showsSafari) {
            if let url = ranked.item.link {
                SafariView(url: url)
            }
        }
        // 正文中保留的"查看全文"链接，同样用内置 Safari 打开
        .sheet(isPresented: Binding(
            get: { bodyLink != nil },
            set: { if !$0 { bodyLink = nil } }
        )) {
            if let url = bodyLink {
                SafariView(url: url)
            }
        }
        .onAppear {
            viewModel.onAppear(repository: repository)
        }
        .onDisappear {
            // 触发首页在返回时重建已读态
        }
    }

    private var hasBody: Bool {
        !ranked.item.contentHTML.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var metaRow: some View {
        HStack(spacing: 6) {
            Text(sourceTitle)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppColors.brand)
            Text("·")
                .font(.caption)
                .foregroundStyle(AppColors.tertiaryText)
            Text(DateFormatting.relativeText(from: ranked.item.publishedAt))
                .font(.caption)
                .foregroundStyle(AppColors.tertiaryText)
            if let author = ranked.item.author, !author.isEmpty {
                Text("·")
                    .font(.caption)
                    .foregroundStyle(AppColors.tertiaryText)
                Text(author)
                    .font(.caption)
                    .foregroundStyle(AppColors.tertiaryText)
            }
            Spacer()
            Text("已读")
                .font(.caption2)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(AppColors.screenBackground)
                .clipShape(Capsule())
                .foregroundStyle(AppColors.tertiaryText)
        }
    }

    private var sourceTitle: String {
        if let stored = repository.allStoredSources().first(where: { $0.uuid == ranked.sourceID }) {
            return stored.title
        }
        return "未知来源"
    }
}
