import SwiftUI
import SwiftData
import MillaCore

/// 设置页：订阅源管理、排序权重、抽样参数。
struct SettingsView: View {

    @Environment(FeedRepository.self) private var repository
    @Environment(AppSettings.self) private var settings

    @State private var viewModel = SettingsViewModel()
    @State private var didLoad = false

    var body: some View {
        @Bindable var settings = settings

        Form {
            rankingSection(settings: settings)
            defaultValuesSection(settings: settings)
            sourcesSection
            aboutSection
        }
        .navigationTitle("设置")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    viewModel.draftTitle = ""
                    viewModel.draftURL = ""
                    viewModel.isPresentingAddSheet = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("添加订阅源")
            }
        }
        .sheet(isPresented: $viewModel.isPresentingAddSheet) {
            addSourceSheet
        }
        .alert("无法添加", isPresented: $viewModel.showsError, presenting: viewModel.errorText) { _ in
            Button("知道了", role: .cancel) {}
        } message: { text in
            Text(text)
        }
        .onAppear {
            viewModel.load(repository: repository)
        }
    }

    // MARK: Sections

    @ViewBuilder
    private func rankingSection(settings: Bindable<AppSettings>) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("质量权重")
                    Spacer()
                    Text(String(format: "%.2f", settings.qualityWeight.wrappedValue))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                Slider(value: settings.qualityWeight, in: 0...1, step: 0.05)
                Text("新鲜度权重自动补为 \(String(format: "%.2f", 1 - settings.qualityWeight.wrappedValue))，排序前会再做归一化。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Stepper(value: settings.recencyHalfLifeHours,
                    in: 6...72, step: 6) {
                HStack {
                    Text("新鲜度半衰期")
                    Spacer()
                    Text("\(Int(settings.recencyHalfLifeHours.wrappedValue)) 小时")
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }

            Toggle("随机加权抽样", isOn: settings.stochasticSampling)
        } header: {
            Text("信息流排序")
        } footer: {
            Text("默认 质量 0.6 / 新鲜度 0.4；抽样默认使用确定性 Top-K，结果稳定可回归。")
        }
    }

    @ViewBuilder
    private func defaultValuesSection(settings: Bindable<AppSettings>) -> some View {
        Section("新订阅源默认参数") {
            Stepper(value: settings.defaultDailyLimit, in: 1...30) {
                HStack {
                    Text("每日最大条数")
                    Spacer()
                    Text("\(settings.defaultDailyLimit.wrappedValue)")
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
            Stepper(value: settings.defaultSampleSize, in: 1...20) {
                HStack {
                    Text("每日抽样数")
                    Spacer()
                    Text("\(settings.defaultSampleSize.wrappedValue)")
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
            VStack(alignment: .leading) {
                HStack {
                    Text("默认质量分")
                    Spacer()
                    Text(String(format: "%.2f", settings.defaultQualityScore.wrappedValue))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                Slider(value: settings.defaultQualityScore, in: 0.1...1, step: 0.05)
            }
        }
    }

    private var sourcesSection: some View {
        Section {
            if viewModel.sources.isEmpty {
                Text("还没有订阅源，点击右上角 + 添加 RSS / Atom 地址。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            ForEach(viewModel.sources, id: \.uuid) { source in
                NavigationLink {
                    FeedSourceEditView(
                        source: source,
                        repository: repository,
                        onChanged: { viewModel.load(repository: repository) },
                        onDeleted: { viewModel.load(repository: repository) }
                    )
                } label: {
                    HStack {
                        Circle()
                            .fill(source.isEnabled ? AppColors.brand : Color.gray.opacity(0.4))
                            .frame(width: 8, height: 8)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(source.title)
                                .font(.body)
                            Text(source.urlString)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Spacer()
                    }
                }
            }
            .onDelete { offsets in
                viewModel.delete(at: offsets, repository: repository)
            }
        } header: {
            Text("订阅源（\(viewModel.sources.count)）")
        }
    }

    private var aboutSection: some View {
        Section("关于") {
            Toggle("启动时自动刷新", isOn: Binding(
                get: { settings.refreshOnLaunch },
                set: { settings.refreshOnLaunch = $0 }
            ))
            HStack {
                Text("版本")
                Spacer()
                Text(Self.appVersion)
                    .foregroundStyle(.secondary)
            }
            HStack {
                Text("最低系统")
                Spacer()
                Text("iOS 18")
                    .foregroundStyle(.secondary)
            }
            LabeledContent("核心算法") {
                Text("MillaCore（纯 Swift，可跨平台测试）")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var addSourceSheet: some View {
        NavigationStack {
            Form {
                Section("订阅源信息") {
                    TextField("名称（可选）", text: $viewModel.draftTitle)
                    TextField("https://example.com/feed.xml", text: $viewModel.draftURL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                Section {
                    Text("添加后会立即尝试拉取；每日条数、抽样数和质量分可在订阅源详情中调整。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("添加订阅源")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { viewModel.isPresentingAddSheet = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("添加") {
                        viewModel.addDraft(repository: repository, settings: settings)
                    }
                    .disabled(viewModel.draftURL.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    static var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}

// MARK: - 单个订阅源编辑

private struct FeedSourceEditView: View {

    @Bindable var source: StoredFeedSource
    let repository: FeedRepository
    let onChanged: () -> Void
    let onDeleted: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            Section("订阅源") {
                Toggle("启用该订阅源", isOn: Binding(
                    get: { source.isEnabled },
                    set: { source.isEnabled = $0; save() }
                ))
                TextField("名称", text: Binding(
                    get: { source.title },
                    set: { source.title = $0; save() }
                ))
                Text(source.urlString)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("每日更新") {
                Stepper(value: binding(\.dailyLimit), in: 0...30) {
                    HStack {
                        Text("每日最大条数")
                        Spacer()
                        Text(source.dailyLimit == 0 ? "不限" : "\(source.dailyLimit)")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
                Stepper(value: binding(\.sampleSize), in: 0...20) {
                    HStack {
                        Text("每日抽样数")
                        Spacer()
                        Text(source.sampleSize == 0 ? "同最大条数" : "\(source.sampleSize)")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
            }

            Section {
                VStack(alignment: .leading) {
                    HStack {
                        Text("质量评分")
                        Spacer()
                        Text(String(format: "%.2f", source.qualityScore))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    Slider(value: binding(\.qualityScore), in: 0.1...1, step: 0.05)
                }
            } header: {
                Text("质量权重")
            } footer: {
                Text("质量分越高，该源在综合排序中的竞争力越强。")
            }

            if let lastFetched = source.lastFetchedAt {
                Section("状态") {
                    LabeledContent("最近成功更新") {
                        Text(DateFormatting.relativeText(from: lastFetched))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section {
                Button(role: .destructive) {
                    repository.delete(source)
                    onDeleted()
                    dismiss()
                } label: {
                    Label("删除订阅源", systemImage: "trash")
                }
            }
        }
        .navigationTitle(source.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func binding<Value>(_ keyPath: ReferenceWritableKeyPath<StoredFeedSource, Value>)
        -> Binding<Value> {
        Binding(
            get: { source[keyPath: keyPath] },
            set: { source[keyPath: keyPath] = $0; save() }
        )
    }

    private func save() {
        repository.persistPendingChanges()
        onChanged()
    }
}
