# Milla — 极简 RSS 信息流阅读器

<p align="center">
  <img src="Milla/Resources/Assets.xcassets/AppIcon.appiconset/icon.png" width="120" alt="Milla 图标" />
</p>

Milla 把你订阅的网站变成一份干净的「个人报纸」：上下滑动浏览卡片，多来源交替出现，
一个源再高产也不会霸屏。没有算法推荐、没有广告、没有跟踪——只有你自己选的内容，
按你定的规则排序。

- 平台：iPhone / iOS 18+
- 价格：免费开源
- 隐私：所有数据只存在你的手机里，不经过任何第三方服务器

---

## 功能

**📖 多源交替信息流**
每个订阅源都有出场配额，虎嗅、少数派、知乎日报……轮流上阵，相邻两条必不同源。

**🧊 只增不换的时间线**
下拉刷新只会把新文章放到最上面，绝不会把你没看完的旧文章搅乱或移走。已读的文章也安安静静待在原地。

**🫧 干净的阅读页**
自动去掉原网页的导航栏、页脚链接、"扫码关注"之类的杂物，正文里没有可点的乱入链接；
开头重复出现的"编者导语"也会自动识别删除。封面图按屏幕宽度完整展示。

**🎚️ 排序规则你说了算**
每个源可单独设置"质量星级""每日条数上限""每次出场条数"；全局可调"质量 vs 新鲜"的偏好。
改规则只影响以后新来的文章，不动你现有的时间线。

**🎨 舒适的观感**
跟随系统 / 浅色 / 深色三种外观模式；系统级大字号无障碍适配。

---

## 安装

Milla 目前未上架 App Store，有两种获取方式：

**方式一：自己编译（推荐，免费且无需开发者账号）**

1. 准备一台 Mac，安装 [Xcode](https://apps.apple.com/app/xcode/id497799835)；
2. 下载本仓库代码：
   ```bash
   git clone https://github.com/freepotato/Milla-Feed.git
   cd Milla-Feed
   ```
3. 用 [XcodeGen](https://github.com/yonaskolb/XcodeGen/releases) 生成工程并打开：
   ```bash
   xcodegen generate
   open Milla.xcodeproj
   ```
4. 在 Xcode 顶部选一台 iPhone 模拟器或你的 iPhone，按 ⌘R 运行；
   装真机时如提示"不受信任的开发者"，去 设置 → 通用 → VPN与设备管理 信任你的 Apple ID。

详细的构建环境说明（双 Xcode、真机签名、Windows 验证）见
[技术文档 · 构建章节](docs/TECHNICAL.md#5-mac-端-ios-27-运行与真机安装)。

**方式二：等待 TestFlight / App Store 上架**（见仓库 Release 动态）。

---

## 使用指南

### 添加订阅
首次启动自带 4 个示例源（虎嗅 / 少数派 / 联合早报·中国 / 知乎日报）。
右上角 ⚙️ 进入设置 → **订阅源** → 右上角 **+**，粘贴任何 RSS 地址即可
（RSS 地址通常是 `网站域名/feed` 或 `网站域名/rss`）。

### 下拉刷新
首页下拉即可更新全部订阅源。新文章会出现在列表**最顶部**，旧文章的位置永远不变。

### 阅读文章
点卡片进入阅读页：星号 ★ 收藏，罗盘 ◯ 用 Safari 打开原文。
返回首页时这篇文章会自动标记为已读（变灰），但仍然留在原位。

### 调整排序口味
设置 → **排序参数**：

| 想要的效果 | 怎么调 |
|---|---|
| 更看重"最近发布"的文章 | 调高 **新鲜度权重**（或缩短半衰期） |
| 更信任高质量来源 | 调高 **质量权重** |
| 某个源出现得太频繁 | 调低该源的 **每日上限 / 出场条数** |
| 某个源老是抢头条 | 调低该源的 **质量星级** |
| 想偶尔看到"惊喜"内容 | 打开 **随机抽样** |

参数背后的原理见 [算法通俗讲解](docs/RANKING-EXPLAINED.md)。

---

## 常见问题

**Q：为什么下拉刷新后，有些文章的顺序完全没变？**
这是设计特性：旧文章顺序永久固定，排序只决定"新文章这一批"的先后。
没有新文章时，信息流会保持原样。

**Q：为什么有的文章点开只显示一两行？**
部分源（如 Hacker News）本身在 RSS 里只给链接不给正文。此时阅读页会提示，
你可以点右上角罗盘去原站阅读。

**Q：为什么某条新闻显示"3 个月前"却排在很上面？**
少数公共镜像源的日期数据不准确。文章按你设置的权重排序，旧文章若来自高质量源也可能靠前；
也可以直接降低该源的星级。

**Q：删除订阅源后，它以前的文章去哪了？**
会一并删除（订阅源下的文章跟源绑定）。

**Q：会加 Android / iPad 版吗？**
iPad 布局在计划中（见 [技术文档 · 迭代清单](docs/TECHNICAL.md#9-后续可迭代功能清单)）；
Android 暂无计划，但核心排序算法是跨平台 Swift 包，理论上可复用。

---

## 给开发者

- [技术文档 TECHNICAL.md](docs/TECHNICAL.md) —— 架构、目录、构建步骤、CI/发版流程、iOS 27 适配策略
- [算法通俗讲解 RANKING-EXPLAINED.md](docs/RANKING-EXPLAINED.md) —— 信息流排序与质量分级原理，以及后续改进方向
- 核心算法是独立的纯 Swift 包（`Packages/MillaCore`），在 macOS / Windows / Linux 上都能跑测试
- 版本发布：提交遵循 Conventional Commits（`feat:` → minor，`fix:` → patch），
  [release-please](https://github.com/googleapis/release-please) 自动维护 CHANGELOG，
  发版记录见 [Releases](https://github.com/freepotato/Milla-Feed/releases)
