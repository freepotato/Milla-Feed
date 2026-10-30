# Milla 技术文档（TECHNICAL）

> 本文档面向开发者与维护者，是从 README 拆分出来的技术概述。
> 如果你只想了解怎么用 Milla、怎么调排序参数，请回到 [README](../README.md)；
> 想深入理解排序算法的原理与调参思路，请阅读 [算法通俗讲解](RANKING-EXPLAINED.md)。

极简 iOS RSS 信息流阅读器，纯 SwiftUI + MVVM + `@Observable`。
核心算法在纯 Swift SPM 包 **MillaCore**，可在 macOS / Windows / Linux 上直接 `swift test`。

- 最低部署目标：**iOS 18**；主力调试：**iOS 27 / Xcode 27 Beta**
- 依赖管理：**SPM**（本地包），无 Alamofire 等重型依赖
- 工程生成：**XcodeGen**（`project.yml` 为唯一事实来源，`Milla.xcodeproj` 不进 Git，双机无冲突）

---

## 目录

1. [项目架构设计](#1-项目架构设计)
2. [信息流排序算法伪代码](#2-信息流排序算法伪代码)
3. [完整目录结构](#3-完整目录结构)
4. [核心文件代码](#4-核心文件代码)
5. [Mac 端 iOS 27 运行与真机安装](#5-mac-端-ios-27-运行与真机安装)
6. [Windows 端可验证内容清单](#6-windows-端可验证内容清单)
7. [GitHub + release-please 接入步骤](#7-github--release-please-接入步骤)
8. [iOS 27 适配清单与 iOS 18 兼容策略](#8-ios-27-适配清单与-ios-18-兼容策略)
9. [后续可迭代功能清单](#9-后续可迭代功能清单)

---

## 1. 项目架构设计

### 1.1 分层

```
┌──────────────────────────────────────────────────────────┐
#  iOS App（Milla/，仅在 Mac + Xcode 编译）                  │
│  SwiftUI Views ── @Observable ViewModels ── Services      │
│   Home/Settings/Article        │           │              │
│                                ▼           ▼              │
│                     FeedSyncService   FeedRepository      │
│                     (URLSession)      (SwiftData)         │
│                                │           │              │
│  XMLParserFeedParser(首选) ────┤           │              │
└────────────────────────────────┼───────────┼──────────────┘
                                 ▼           ▼
┌──────────────────────────────────────────────────────────┐
#  MillaCore（Packages/MillaCore，纯 Swift，跨平台）          │
│  FeedSource / FeedItem（值类型 + Codable）                 │
│  FeedParsing: SwiftFeedParser（纯 Swift，Windows 可用）    │
│  FeedRankingService（dailyLimit/sample/权重/交替/去重）     │
│  RankingConfiguration / StableIdentifier / SampleData     │
│  ContentSanitizer（正文净化）                              │
│  milla-cli（命令行自检 + fixtures 排序）                    │
└──────────────────────────────────────────────────────────┘
```

### 1.2 MVVM 职责

| 层 | 类型 | 技术 | 职责 |
|---|---|---|---|
| View | `HomeView` / `SettingsView` / `ArticleView` / `FeedCardView` | SwiftUI 原生组件 | 只做展示与事件绑定 |
| ViewModel | `HomeViewModel` 等 | `@Observable` | 编排：拉取 → 取快照 → 仅对新增批次调 MillaCore 排序 → 置顶追加 |
| Service | `FeedSyncService` | URLSession async/await | 并发拉取、逐源容错、解析器回退（含正文净化） |
| Parser | `XMLParserFeedParser` / `SwiftFeedParser` / `ContentSanitizer` | XMLParser / 自研分词器 / 规则净化 | RSS 2.0 + Atom 解析、导航页脚噪声与重复导入语清理 |
| Repository | `FeedRepository` | SwiftData + UserDefaults | 订阅源、文章、已读、收藏、信息流顺序与已见池持久化 |
| Settings | `AppSettings` | UserDefaults | 权重、半衰期、默认抽样参数 |
| Core | `FeedRankingService` 等 | 纯 Foundation | **无任何 iOS 依赖**，Windows 可测 |

### 1.3 关键设计决策

- **排序算法与 UI 解耦**：算法只接收 `[FeedSource]` / `[FeedItem]` / 配置 / 注入时钟，纯函数输出 `[RankedFeedItem]`，可复现、可回归。
- **双解析器**：iOS 优先用系统 `XMLParser`（符合“优先原生”要求）；解析失败自动回退到 MillaCore 的纯 Swift 解析器。后者也是 Windows 测试与 CLI 的基准实现，两者输出同构。
- **正文净化在解析层**：导航/页脚/分享/订阅类噪声块、HN 样板行、全部超链接、与正文重复的开头导入语，都在 `ContentSanitizer` 中于入库前清除，渲染层只拿干净 HTML。
- **稳定内容 ID**：`FNV-1a64(订阅源ID + guid/link/title)`，多次拉取、多设备重建数据库后仍可被去重池识别，不依赖 CryptoKit。
- **工程文件不进 Git**：`project.yml` 描述工程，Mac 上 `xcodegen generate` 生成，Windows/Mac 之间不会出现 pbxproj 冲突。

---

## 2. 信息流排序算法伪代码

参数：`dailyLimit`、`sampleSize`（每源）、`qualityScore`（每源 0...1）、
`qualityWeight = 0.6`、`recencyWeight = 0.4`（可在设置页调整，排序前归一化）。

```text
输入: sources[], items[], shownIDs(去重池), config, now(可注入时钟)

recencyScore(publishedAt):
    if publishedAt == nil: return config.missingDateRecency   // 默认 0.25
    ageHours = max(0, now - publishedAt)
    return 0.5 ^ (ageHours / halfLifeHours)                   // 默认半衰期 24h

rank(sources, items, shownIDs, config, now):
    sources = sources.filter { $0.isEnabled }
    items   = items.filter { source 存在且启用 }
    excludedAsShown = items 中 id ∈ shownIDs 的条目
    items   = items.filter { id ∉ shownIDs }

    queues = []
    for source in sources:
        # —— 步骤 2：当日候选 ——
        candidates = items(from: source).filter { 发布于 now 当天 }
        if candidates 为空:
            candidates = 该源最新的条目           # 低频源兜底，不彻底消失

        # —— 步骤 3：dailyLimit 截断（0 = 不限）——
        candidates = candidates.按发布时间倒序.prefix(source.dailyLimit)

        # —— 打分 ——
        scored = candidates.map { item in
            r = recencyScore(item.publishedAt)
            q = source.qualityScore
            score = qualityWeight*q + recencyWeight*r
        }

        # —— 步骤 4：抽样 sampleSize ——
        sampled = 默认: 确定性 Top-K(score)                      # 稳定可回归
                  可选: Efraimidis–Spiliotidis 加权随机抽样(可带种子)
        queues[source] = sampled.按 score 降序

    # —— 步骤 5/6：贪心交替合并（多源防霸屏）——
    result = []
    lastSourceID = nil
    while 任一队列非空:
        候选 = 队列中“队首条目 sourceID ≠ lastSourceID”的源
              （若剩余条目全部同源，则允许同源）
        选择: 候选中队首 score 最高的源（平分时取源顺序靠前）
        result.append(该条目); lastSourceID = 该源
    return RankingOutcome(result, excludedAsShown)
```

首页顺序规则（产品取舍，App 层在算法之上的编排）：

1. **文章只增不换**：下拉刷新不会重排或移除旧文章，已读文章同样保留在信息流中；
2. **排序只作用于新增批次**：质量/时效权重与抽样仅对"本次新抓取的文章"生效，
   新批次按排序结果整体置顶，旧文章顺序永久保持（顺序持久化在 UserDefaults，
   重启 App 不变）；
3. "已见池"独立于展示顺序：首批抽样未中的文章记入已见池，以后不会冒充新内容；
4. 已读/收藏独立维护，收藏内容不会丢失入口（后续"收藏列表"直接读 SwiftData）。

> 上面伪代码中的 `shownIDs` 是算法层保留的可选去重参数；当前 App 编排对每个
> 新增批次传入空集，去重与顺序语义由 App 层的"顺序表 + 已见池"承担。

交替合并保证：**只要 ≥2 个源还有候选，相邻两条不可能来自同一源**；同时在交替约束内始终优先综合分最高的条目。

算法思想、参数含义与调参实践的通俗版本见 [算法通俗讲解](RANKING-EXPLAINED.md)。

---

## 3. 完整目录结构

```text
Milla-Feed/
├── project.yml                         # XcodeGen 工程描述（Git 内）
├── release-please-config.json          # release-please 配置（swift 策略）
├── .release-please-manifest.json       # 当前版本 0.1.0
├── Design/                             # 图标 SVG 源稿
├── docs/
│   ├── TECHNICAL.md                    # 本文档
│   └── RANKING-EXPLAINED.md            # 排序算法通俗讲解
├── Fixtures/                           # CLI / 测试用真实 RSS 样例
│   ├── sources.json
│   ├── techpulse.xml                   # RSS 2.0 + media/content/dc
│   ├── worldwire.xml                   # RSS 2.0 + enclosure
│   └── designdaily.xml                 # Atom
├── Scripts/
│   ├── verify-core.sh                  # macOS/Linux 验证
│   ├── verify-core.ps1                 # Windows 验证
│   └── sync-version.sh                 # Git tag -> project.yml -> xcodegen
├── .github/workflows/
│   ├── release.yml                     # release-please（feat->minor fix->patch）
│   └── core.yml                        # MillaCore CI（macOS + Ubuntu）
├── Packages/
│   └── MillaCore/                      # ★ 纯 Swift，跨平台
│       ├── Package.swift
│       └── Sources/
│           ├── MillaCore/
│           │   ├── Models/             # FeedSource / FeedItem / StableIdentifier
│           │   ├── Parsing/            # FeedParser / SwiftFeedParser / HTMLText / FeedDateParser / ContentSanitizer
│           │   ├── Ranking/            # FeedRankingService / RankingConfiguration
│           │   └── SampleData.swift
│           └── milla-cli/              # 命令行：rank / verify / --json
│       └── Tests/MillaCoreTests/       # XCTest（算法 + 解析器 + 净化器）
├── Milla/                              # ★ iOS App target
│   ├── App/
│   │   ├── MillaApp.swift              # @main、SwiftData 容器、环境注入
│   │   ├── RootView.swift              # NavigationStack + Route
│   │   └── AppRouter.swift
│   ├── Features/
│   │   ├── Home/{HomeView,HomeViewModel}.swift
│   │   ├── Settings/{SettingsView,SettingsViewModel}.swift
│   │   └── Article/{ArticleView,ArticleViewModel,HTMLTextView,SafariView}.swift
│   ├── Persistence/
│   │   ├── StoredFeedSource.swift      # SwiftData @Model ↔ FeedSource
│   │   ├── StoredFeedArticle.swift     # SwiftData @Model ↔ FeedItem
│   │   └── FeedRepository.swift
│   ├── Services/
│   │   ├── AppSettings.swift           # UserDefaults（权重等）
│   │   ├── FeedSyncService.swift       # URLSession 并发拉取
│   │   ├── XMLParserFeedParser.swift   # 原生 XMLParser
│   │   └── DefaultFeeds.swift
│   ├── MillaUITests/                   # XCUITest 冒烟（阅读流 + 详情页）
│   ├── Compatibility/
│   │   └── PlatformFeatures.swift      # iOS 27 新 API 唯一挂载点（含模板）
│   ├── UI/
│   │   ├── Components/{FeedCardView,TopBannerView,EmptyStateView}.swift
│   │   └── Theme/{AppColors,AppSpacing,DateFormatting}.swift
│   └── Resources/
│       ├── Info.plist
│       └── Assets.xcassets/            # AppIcon(1024 PNG) + AccentColor
```

> 说明：需求模板中的 `Models/`、`Services/RSSParserService.swift`、`FeedRankingService.swift`
> 被有意下沉到 `Packages/MillaCore`，这是“Windows 可验证算法”的必要拆分；
> iOS 端的类型映射与平台服务位于 `Milla/Persistence` 与 `Milla/Services`。

---

## 4. 核心文件代码

以下列出关键实现位置，完整代码见仓库文件。

### 4.1 排序核心（纯 Swift）

- [FeedRankingService.swift](file:///Users/florian/Documents/Milla-Feed/Packages/MillaCore/Sources/MillaCore/Ranking/FeedRankingService.swift)
  — `recencyScore`、`rank(sources:items:shownIdentifiers:config:now:calendar:)`、
  `dailyCandidates`、确定性/加权随机 `sample`、贪心 `interleave`。
- [RankingConfiguration.swift](file:///Users/florian/Documents/Milla-Feed/Packages/MillaCore/Sources/MillaCore/Ranking/RankingConfiguration.swift)
  — 默认 `0.6 / 0.4`、半衰期、随机开关与种子、权重归一化。
- [StableIdentifier.swift](file:///Users/florian/Documents/Milla-Feed/Packages/MillaCore/Sources/MillaCore/Models/StableIdentifier.swift)
  — FNV-1a64 跨平台稳定 ID。

### 4.2 RSS 解析

- [SwiftFeedParser.swift](file:///Users/florian/Documents/Milla-Feed/Packages/MillaCore/Sources/MillaCore/Parsing/SwiftFeedParser.swift)
  — 自研 XML 分词器（CDATA、实体、命名空间）+ RSS 2.0 / Atom 构建器。
- [XMLParserFeedParser.swift](file:///Users/florian/Documents/Milla-Feed/Milla/Services/XMLParserFeedParser.swift)
  — App 端首选的原生 `XMLParser` 实现。
- [HTMLText.swift](file:///Users/florian/Documents/Milla-Feed/Packages/MillaCore/Sources/MillaCore/Parsing/HTMLText.swift)
  — 摘要去标签、实体解码、封面图提取。
- [ContentSanitizer.swift](file:///Users/florian/Documents/Milla-Feed/Packages/MillaCore/Sources/MillaCore/Parsing/ContentSanitizer.swift)
  — 正文净化：去导航/页脚/样板噪声、剥离超链接、删除与正文重复的开头导入语。

### 4.3 iOS 端编排

- [HomeViewModel.swift](file:///Users/florian/Documents/Milla-Feed/Milla/Features/Home/HomeViewModel.swift)
  — 首批全量排序一次；之后仅对"已见池"之外的新文章排序，新批次置顶、旧顺序不动。
- [FeedSyncService.swift](file:///Users/florian/Documents/Milla-Feed/Milla/Services/FeedSyncService.swift)
  — `withTaskGroup` 并发、逐源隔离错误、双解析器回退。
- [FeedRepository.swift](file:///Users/florian/Documents/Milla-Feed/Milla/Persistence/FeedRepository.swift)
  — SwiftData 增删改查、已读/收藏，UserDefaults 持久化信息流顺序与已见池；文章不自动删除。

### 4.4 页面

- [HomeView.swift](file:///Users/florian/Documents/Milla-Feed/Milla/Features/Home/HomeView.swift)
  — 顶部横幅（ScrollView 首项，拉到顶端才显示）+ 卡片流 + 下拉刷新。
- [FeedCardView.swift](file:///Users/florian/Documents/Milla-Feed/Milla/UI/Components/FeedCardView.swift)
  — 圆角卡片、`AsyncImage` 封面、标题/摘要/来源/时间。
- [SettingsView.swift](file:///Users/florian/Documents/Milla-Feed/Milla/Features/Settings/SettingsView.swift)
  — 权重滑块、半衰期、每源 dailyLimit/sampleSize/质量分、添加/删除/启停。
- [ArticleView.swift](file:///Users/florian/Documents/Milla-Feed/Milla/Features/Article/ArticleView.swift)
  — 标题/来源/时间/正文、Safari 打开原文、已读自动标记、收藏。

### 4.5 命令行

```bash
cd Packages/MillaCore
swift run milla-cli verify                 # 20 项内置自检（无需 Xcode/XCTest）
swift test                                 # XCTest 完整用例
swift run milla-cli                        # 内置样例数据排序演示
swift run milla-cli rank ../../Fixtures    # 真实 RSS 样例排序
swift run milla-cli --quality 0.8 --recency 0.2 --json
```

实测输出（交替防霸屏效果）：

```text
 1. [TechPulse]   score=0.938  12分钟前  · TechPulse #1 刚刚发布
 2. [DesignDaily] score=0.869  1小时前   · DesignDaily 封面设计趋势
 3. [TechPulse]   score=0.931  48分钟前  · TechPulse #2
 4. [DesignDaily] score=0.836  4小时前   · DesignDaily 字体排印笔记
 5. [TechPulse]   score=0.923  2小时前   · TechPulse #3
 6. [WorldWire]   score=0.754  30分钟前  · WorldWire 突发一条
 7. [SlowWeek]    score=0.500  1天前     · SlowWeek 周报（昨天）
 ...
```

---

## 5. Mac 端 iOS 27 运行与真机安装

> 本节所有步骤**只能在 Mac 上完成**。

### 5.1 一次性环境准备

1. 安装 **Xcode 27 Beta**（iOS 27 真机/模拟器调试），保留 **Xcode 26**（App Store 合规构建）：
   ```bash
   # 两个版本并存，用 xcode-select 切换
   sudo xcode-select -s /Applications/Xcode-27-beta.app/Contents/Developer
   ```
2. 安装 XcodeGen 并生成工程：
   ```bash
   brew install xcodegen
   cd /path/to/Milla-Feed
   xcodegen generate          # 生成 Milla.xcodeproj（已被 .gitignore）
   ```
   > macOS 27 等预发布版可能暂无 Homebrew bottle，此时直接下载官方预编译包：
   > [Releases · yonaskolb/XcodeGen](https://github.com/yonaskolb/XcodeGen/releases/latest)
   > 下载 `xcodegen.zip`，解压后将 `xcodegen/bin/xcodegen` 放入 `PATH`（如
   > `/opt/homebrew/bin`）即可；国内网络可经 gh-proxy 镜像加速下载。
3. 打开工程：`open Milla.xcodeproj`，在 target *Milla → Signing & Capabilities* 选择你的
   Development Team。Bundle Identifier 已固化为 `com.florian.millafeed`（在 `project.yml`
   中维护，不要只在 Xcode 里改，重新生成会被覆盖）。

### 5.2 日常调试

- SwiftUI Preview：直接在任意 `#Preview` 中查看（已提供 TopBanner / FeedCard / 首页预览）。
- 模拟器：选 iPhone 17 系列模拟器，⌘R。
- iOS 27 真机：设置 → 隐私与安全性 → 开发者模式，选真机后 ⌘R；
  免费账号 7 天有效，付费账号可调试签名一年。
- 修改 `project.yml` 或新增/删除文件后，重新跑一次 `xcodegen generate`（在 Xcode 中无需关闭工程）。
- UI 冒烟测试：`xcodebuild test -project Milla.xcodeproj -scheme Milla -destination 'platform=iOS Simulator,name=iPhone 17'`
  （含信息流打开文章与第二篇文章的可读性回归用例）。

### 5.3 安装到 iPhone（无需 TestFlight 的开发安装）

1. 真机用数据线连接并在“是否信任此电脑”点信任；
2. Xcode 顶部目标选你的 iPhone；
3. ⌘R 自动编译、签名、安装并启动；
4. 若提示“不受信任的开发者”：iPhone → 设置 → 通用 → VPN与设备管理 → 信任你的 Apple ID。

### 5.4 TestFlight / App Store

- 合规构建使用 **Xcode 26 + iOS 26 SDK**：
  `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer` 后再 Archive；
- Xcode 27 Beta 产物可用于真机开发与 TestFlight 内测，但**正式提审用 Xcode 26**；
- Product → Archive → Distribute App → App Store Connect → TestFlight。

> 图标资产注意：Xcode 27 的 actool **不接受 SVG 应用图标**（报 "not a valid extension"），
> 也不接受带 Alpha 通道的 PNG。流程为：`Design/icon.svg` → `qlmanage -t -s 1024` 渲染 →
> 压平为无 Alpha 的 1024×1024 PNG → 覆盖 `AppIcon.appiconset/icon.png`；
> `Contents.json` 需带 `"size": "1024x1024"` 与 default/dark/tinted 三个槽位。

---

## 6. Windows 端可验证内容清单

Windows 只做编辑 / Git / 算法验证 / 发版管理，**不运行 iOS 模拟器**。

### 6.1 环境

安装 [Swift for Windows](https://www.swift.org/download/)（6.x），在 PowerShell 中：

```powershell
cd Milla-Feed
powershell -ExecutionPolicy Bypass -File Scripts\verify-core.ps1
```

它会依次执行 `milla-cli verify`（20 项自检）与 `swift test`（XCTest，开源 Swift 工具链自带）。

### 6.2 可在 Windows 验证的内容

| 内容 | 手段 |
|---|---|
| RSS 2.0 / Atom 解析（CDATA、实体、media、封面提取） | XCTest + `swift run milla-cli rank Fixtures` |
| dailyLimit 截断 | `FeedRankingServiceTests` / verify 自检 |
| sampleSize 确定性 Top-K 与固定种子随机抽样 | 同上 |
| quality/recency 打分与权重归一化 | 同上 |
| 多源交替（相邻不同源不变量） | 单测断言 |
| 正文净化（噪声块/超链接/重复导入语） | `ContentSanitizerTests`（含真实结构用例） |
| 修改排序参数后的效果 | `--quality/--recency/--half-life/--json` |
| 数据模型、稳定 ID 行为 | 单测 |

### 6.3 不应在 Windows 验证的内容

- 任何 SwiftUI 视图、SwiftData 持久化、`XMLParser` 桥接、真机行为 —— 提交后由
  Mac 的 Xcode Preview / 模拟器 / 真机，以及 GitHub Actions 的 macOS 任务兜底。

> `milla-cli verify`（20/20）与 `swift test` 均已在 macOS 27 + Xcode 27 实跑通过。
> 提示：若项目放在 iCloud 同步的 `~/Documents` 下，`swift test` 的 codesign 可能报
> “resource fork … not allowed”，用 `swift test --scratch-path ~/.cache/millacore-build`
> 把构建目录移出同步目录即可。

---

## 7. GitHub + release-please 接入步骤

### 7.1 首次接入（一次性）

```bash
cd Milla-Feed
git init
git add .
git commit -m "chore: bootstrap Milla rss reader"
git branch -M main
git remote add origin https://github.com/freepotato/Milla-Feed.git
git push -u origin main
```

`release-please-config.json` 使用 `release-type: simple`（新版 release-please 已移除
`swift` 策略；`simple` 同样满足 feat→minor / fix→patch）。

### 7.2 Conventional Commits 规则

| 提交 | 效果 |
|---|---|
| `feat: 新增收藏列表` | minor 升级 `0.1.0 → 0.2.0` |
| `fix: 修复 RFC822 日期解析` | patch 升级 `0.1.0 → 0.1.1` |
| `feat!: 重写同步引擎` | BREAKING CHANGE，major 升级 `1.0.0` |
| `chore/docs/ci/test/refactor` | 不触发版本升级 |

推送到 `main` 后，release-please 会自动开/更新一个 **Release PR**，
里面包含 `CHANGELOG.md` 与版本清单变更；合并该 PR 即自动：打 tag `vX.Y.Z`、创建 GitHub Release。

### 7.3 版本号 / 构建号 / Git tag 对应关系

| 项 | 来源 | 示例 |
|---|---|---|
| Git tag | release-please 自动创建 | `v0.2.0` |
| `MARKETING_VERSION`（CFBundleShortVersionString） | 与 tag 对齐 | `0.2.0` |
| `CURRENT_PROJECT_VERSION`（构建号） | Git 提交总数，单调递增 | `137` |

在 Mac 上同步版本并打开工程：

```bash
git pull
Scripts/sync-version.sh      # 读取最新 v tag，改 project.yml，xcodegen generate
```

之后 Archive 即可。TestFlight 同一 `MARKETING_VERSION` 的每次上传需要不同构建号，
本方案用提交计数，天然单调递增。

### 7.4 SDK 版本策略

- 开发与内测：Xcode 27 Beta / iOS 27 SDK；
- release tag 后在 Mac 上用 Xcode 26 重新 Archive 提审，满足 App Store 当前 SDK 要求；
- 代码中所有 iOS 27 新 API 均需通过 `#if compiler` + `if #available(iOS 27, *)` 双保险
  （见 [PlatformFeatures.swift](file:///Users/florian/Documents/Milla-Feed/Milla/Compatibility/PlatformFeatures.swift)），
  保证 Xcode 26 仍能编译同一份代码。

---

## 8. iOS 27 适配清单与 iOS 18 兼容策略

### 8.1 已落实

- [x] Deployment Target = iOS 18（`project.yml` 与 Info.plist 均已设置）
- [x] 纯 SwiftUI 原生组件（NavigationStack / Form / ScrollView+LazyVStack / AsyncImage /
  Slider / Stepper / Toggle / SFSafariViewController），用 iOS 27 SDK 编译时自动获得
  Liquid Glass 外观，不手写模拟材质
- [x] `@Observable` 状态管理（iOS 17+ API，iOS 18 部署目标下可用）
- [x] 无 `UIScreen.main`、无固定宽高、无设备方向分支；间距使用语义 token
- [x] 布局全部基于 Size Class / Safe Area / 系统容器，NavigationStack 路径驱动导航，
  天然兼容 iPad 分栏与 iPhone Duo / 折叠屏展开态
- [x] 系统动态色（`.label` / `.systemGroupedBackground`），自动深色模式；
  App 内置 跟随系统/浅色/深色 三档外观，全局生效
- [x] Dynamic Type：字体全部用语义字体（headline/body/caption…）
- [x] iOS 27 专属 API 的**唯一挂载点**与接入模板：
  [PlatformFeatures.swift](file:///Users/florian/Documents/Milla-Feed/Milla/Compatibility/PlatformFeatures.swift)

### 8.2 接入 iOS 27.x 新 API 的强制模板

```swift
// 仅能写在 PlatformFeatures.swift（或其扩展中）
#if compiler(>= 6.3)                 // Xcode 27 工具链才认识新符号
if #available(iOS 27.1, *) {
    // Reserved Region / Arrangement View 等真实 API
} else {
    // 必须提供 iOS 18 可用的降级布局
}
#endif
```

- 裸写 iOS 27 符号会让 Xcode 26 的合规构建失败，因此必须双重保护；
- 新 API 未接入前，`millaAdaptiveChrome()` 为空操作，外观完全交给系统。

### 8.3 下探 iOS 18 以下

核心 UI 架构无需调整：所有视图均基于 iOS 17/18 API。
若未来要支持更早系统，原则上只需：

1. `project.yml` 中 `deploymentTarget.iOS` 改为目标版本（最低受 @Observable/SwiftData 限制为 iOS 17）；
2. 替换少量高版本 API（当前无）；
3. 若要低于 iOS 17，则需把 `@Observable` 换为 `ObservableObject`、SwiftData 换为 Core Data，
   属于数据层重写，不影响 MillaCore 与 SwiftUI 视图骨架。

---

## 9. 后续可迭代功能清单

按奥卡姆剃刀排序，需要时再做：

1. **收藏列表 / 已读过滤**（数据已在 SwiftData，只差一个入口视图）
2. 全文本地搜索（Spotlight 索引 `CSSearchableIndex`）
3. Feed 发现：粘贴网站地址自动探测 `<link rel="alternate">`
4. OPML 导入 / 导出与 iCloud 同步（CloudKit + SwiftData）
5. 后台刷新（`BGAppRefreshTask`）与新内容通知
6. 图片预取与缓存（URLCache 调优 / AsyncImage 自定义 URLCache）
7. 摘要 AI 重排、关键词屏蔽、订阅源分组
8. Widget / 锁屏小组件、App Intents、Shortcuts
9. iPad 双栏（NavigationSplitView）与 iPhone Duo 展开态专属布局
10. 多语言（英文本地化）与辅助功能审计（VoiceOver rotors、Dynamic Type XXXXL 走查）

排序算法层面的改进方向（点击反馈学习、动态质量分等）见
[算法通俗讲解](RANKING-EXPLAINED.md) 末尾的"后续改进"一节。

---

## 附：常用命令速查

```bash
# Mac
xcodegen generate                 # 生成 Xcode 工程
Scripts/sync-version.sh           # release tag -> 版本号同步
Scripts/verify-core.sh            # 核心逻辑验证

# Windows / 跨平台
Scripts/verify-core.ps1
swift run --package-path Packages/MillaCore milla-cli rank Fixtures
```
