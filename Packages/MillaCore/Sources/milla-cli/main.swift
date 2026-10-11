//
//  milla-cli —— 在 Windows / Linux / macOS 上无需 Xcode 验证排序算法。
//
//  用法：
//    swift run milla-cli                      # 使用内置样例数据
//    swift run milla-cli --quality 0.7 --recency 0.3
//    swift run milla-cli rank <fixtures目录>  # 解析目录中的真实 RSS（需含 sources.json）
//    swift run milla-cli --json               # 输出 JSON
//

import Foundation
import MillaCore

// MARK: - 参数解析

struct CLIArguments {
    var quality: Double = 0.6
    var recency: Double = 0.4
    var halfLife: Double = 24
    var jsonOutput = false
    var fixturesDirectory: String?
    var runSelfCheck = false
}

func parseArguments(_ args: [String]) -> CLIArguments? {
    var result = CLIArguments()
    var index = 0
    while index < args.count {
        switch args[index] {
        case "--quality":
            index += 1
            guard index < args.count, let value = Double(args[index]) else { return nil }
            result.quality = value
        case "--recency":
            index += 1
            guard index < args.count, let value = Double(args[index]) else { return nil }
            result.recency = value
        case "--half-life":
            index += 1
            guard index < args.count, let value = Double(args[index]) else { return nil }
            result.halfLife = value
        case "--json":
            result.jsonOutput = true
        case "rank":
            index += 1
            guard index < args.count else { return nil }
            result.fixturesDirectory = args[index]
        case "verify":
            result.runSelfCheck = true
        case "-h", "--help":
            return nil
        default:
            return nil
        }
        index += 1
    }
    return result
}

let usage = """
milla-cli — Milla RSS 排序算法跨平台验证工具

用法:
  swift run milla-cli [--quality 0.6] [--recency 0.4] [--half-life 24] [--json]
  swift run milla-cli rank <fixtures目录> [--json]
  swift run milla-cli verify

示例:
  swift run milla-cli
  swift run milla-cli --quality 0.8 --recency 0.2
  swift run milla-cli rank Fixtures
  swift run milla-cli verify
"""

guard let arguments = parseArguments(Array(CommandLine.arguments.dropFirst())) else {
    FileHandle.standardError.write(Data((usage + "\n").utf8))
    exit(CommandLine.arguments.count <= 1 ? 0 : 1)
}

if arguments.runSelfCheck {
    exit(Verifier.run())
}

// MARK: - 数据装载

let config = RankingConfiguration(
    qualityWeight: arguments.quality,
    recencyWeight: arguments.recency,
    recencyHalfLifeHours: arguments.halfLife
)

let now = Date()
let sources: [FeedSource]
let items: [FeedItem]

if let directory = arguments.fixturesDirectory {
    do {
        let loaded = try loadFixtures(directory: directory)
        sources = loaded.sources
        items = loaded.items
    } catch {
        FileHandle.standardError.write(Data("载入 fixtures 失败: \(error)\n".utf8))
        exit(1)
    }
} else {
    let sample = SampleData.make(now: now)
    sources = sample.sources
    items = sample.items
}

let outcome = FeedRankingService.rank(
    sources: sources,
    items: items,
    config: config,
    now: now
)

// MARK: - 输出

let sourceNames = Dictionary(uniqueKeysWithValues: sources.map { ($0.id, $0.title) })

if arguments.jsonOutput {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes, .sortedKeys]
    encoder.dateEncodingStrategy = .iso8601
    let data = try encoder.encode(outcome.ranked)
    FileHandle.standardOutput.write(data)
    FileHandle.standardOutput.write(Data("\n".utf8))
} else {
    var lines: [String] = []
    lines.append("Milla 排序结果（\(outcome.ranked.count) 条，去重池排除 \(outcome.excludedAsShown.count) 条）")
    lines.append(String(
        format: "权重: quality=%.2f recency=%.2f（归一化后 %.2f / %.2f），半衰期 %.0fh",
        config.qualityWeight,
        config.recencyWeight,
        config.normalizedWeights.quality,
        config.normalizedWeights.recency,
        config.recencyHalfLifeHours
    ))
    lines.append(String(repeating: "-", count: 72))
    for (position, ranked) in outcome.ranked.enumerated() {
        let source = sourceNames[ranked.sourceID] ?? "?"
        let time = ranked.item.publishedAt.map {
            $0.formatted(.relative(presentation: .numeric))
        } ?? "时间未知"
        lines.append(String(
            format: "%2d. [%-11@] score=%.3f (q=%.2f r=%.3f) %@ · %@",
            position + 1,
            source as NSString,
            ranked.score,
            ranked.qualityScore,
            ranked.recencyScore,
            time,
            ranked.item.title
        ))
    }
    print(lines.joined(separator: "\n"))
}

// MARK: - Fixtures

struct FixtureSourceMeta: Codable {
    let title: String
    let fileName: String
    let url: String
    var dailyLimit: Int?
    var sampleSize: Int?
    var qualityScore: Double?
}

func loadFixtures(directory: String) throws -> (sources: [FeedSource], items: [FeedItem]) {
    let directoryURL = URL(fileURLWithPath: directory, isDirectory: true)
    let metaURL = directoryURL.appendingPathComponent("sources.json")
    let metas = try JSONDecoder().decode([FixtureSourceMeta].self, from: Data(contentsOf: metaURL))

    var sources: [FeedSource] = []
    var items: [FeedItem] = []
    let parser = SwiftFeedParser()

    for meta in metas {
        let source = FeedSource(
            title: meta.title,
            url: URL(string: meta.url)!,
            dailyLimit: meta.dailyLimit ?? 10,
            sampleSize: meta.sampleSize ?? 5,
            qualityScore: meta.qualityScore ?? 0.8
        )
        let data = try Data(contentsOf: directoryURL.appendingPathComponent(meta.fileName))
        let parsed = try parser.parse(data: data, source: source)
        sources.append(source)
        items.append(contentsOf: parsed.items)
    }
    return (sources, items)
}
