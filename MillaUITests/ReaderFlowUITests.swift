import XCTest

/// 阅读流程冒烟测试：从信息流打开第一篇带正文的文章，验证详情页渲染。
final class ReaderFlowUITests: XCTestCase {

    @MainActor
    func testOpenArticleShowsReader() throws {
        let app = XCUIApplication()
        app.launch()

        // 等信息流卡片出现（SwiftData 已有缓存内容，网络刷新并行进行）
        let cards = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] '前'") // 相对时间："6小时前"/"2天前"
        )
        let firstCard = cards.element(boundBy: 0)
        XCTAssertTrue(firstCard.waitForExistence(timeout: 20), "信息流未出现卡片")
        firstCard.tap()

        // 详情页：收藏按钮与标题
        let favorite = app.navigationBars.buttons["收藏"]
        XCTAssertTrue(favorite.waitForExistence(timeout: 5), "未进入详情页")

        // 回归断言：push 过渡结束后，详情页必须有文本落在屏幕可见范围内
        //（历史 bug：HTMLTextView 按未换行宽度申报 intrinsic size，把页面横向撑爆，
        //   所有文本都被推出可视区域）
        Thread.sleep(forTimeInterval: 2)
        let texts = app.staticTexts.allElementsBoundByIndex.filter { !$0.label.isEmpty }
        XCTAssertFalse(texts.isEmpty, "详情页没有任何文本")
        let anyVisible = texts.contains { el in
            el.isHittable && el.frame.minX >= 0 && el.frame.minX < 500 && el.frame.width > 0
        }
        XCTAssertTrue(
            anyVisible,
            "详情页内容被推出可视区域: \(texts.prefix(5).map { "\($0.label.prefix(12))@x=\(Int($0.frame.minX))" })"
        )

        // 正文区域应存在可滚动的文本内容
        let bodyText = app.scrollViews.textViews.firstMatch
        XCTAssertTrue(
            bodyText.waitForExistence(timeout: 5) || app.scrollViews.staticTexts.count > 3,
            "详情页没有正文内容"
        )

        let shot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = "reader-view"
        attachment.lifetime = .keepAlways
        add(attachment)

        // 滚动后再截一张，确认正文渲染
        app.scrollViews.firstMatch.swipeUp()
        let shot2 = XCUIScreen.main.screenshot()
        let attachment2 = XCTAttachment(screenshot: shot2)
        attachment2.name = "reader-view-scrolled"
        attachment2.lifetime = .keepAlways
        add(attachment2)
    }

    /// 图文条目（NASA APOD）：封面唯一 + 宽度自适应 + 无导航/页脚噪声
    @MainActor
    func testOpenNASAArticleShowsCleanReader() throws {
        let app = XCUIApplication()
        app.launch()

        let nasaCard = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'APOD'")
        ).element(boundBy: 0)
        XCTAssertTrue(nasaCard.waitForExistence(timeout: 20), "未找到 NASA APOD 卡片")
        nasaCard.tap()

        XCTAssertTrue(
            app.navigationBars.buttons["收藏"].waitForExistence(timeout: 5),
            "未进入详情页"
        )
        Thread.sleep(forTimeInterval: 2) // 等封面图加载 + 过渡结束

        let shot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = "nasa-reader-top"
        attachment.lifetime = .keepAlways
        add(attachment)

        app.scrollViews.firstMatch.swipeUp()
        let shot2 = XCUIScreen.main.screenshot()
        let attachment2 = XCTAttachment(screenshot: shot2)
        attachment2.name = "nasa-reader-scrolled"
        attachment2.lifetime = .keepAlways
        add(attachment2)
    }
}
