import SwiftUI
import MillaCore

/// 文章详情页：标题、来源、时间、正文、打开原文、收藏。
struct ArticleView: View {

    let ranked: RankedFeedItem

    @Environment(FeedRepository.self) private var repository
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: ArticleViewModel
    @State private var showsSafari = false

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
                    AsyncImage(url: imageURL) { phase in
                        switch phase {
                        case .success(let image):
                            // 限高裁切，避免超高竖图占满整屏；
                            // 注意 scaledToFill 必须放在 overlay 里：直接 .fill + frame
                            // 会让图片视图按自身比例向外扩张，横向撑爆外层 ScrollView
                            Color.clear
                                .frame(maxWidth: .infinity, maxHeight: 220)
                                .overlay { image.resizable().scaledToFill() }
                                .clipped()
                        default:
                            RoundedRectangle(cornerRadius: 12)
                                .fill(AppColors.screenBackground)
                                .frame(height: 160)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                Divider()

                if hasBody {
                    HTMLTextView(html: ranked.item.contentHTML)
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
