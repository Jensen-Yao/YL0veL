import XCTest

/// 模拟器截图测试：依次以不同 Tab 启动 App 并截屏（附件导出后作为文档截图）
final class ScreenshotTests: XCTestCase {

    func testCaptureAllTabs() throws {
        let app = XCUIApplication()

        for tab in ["calendar", "insights", "report", "settings", "voice"] {
            app.launchEnvironment["YL_SKIP_DISCLAIMER"] = "1"
            app.launchEnvironment["YL_SEED_DEMO"] = "1"
            app.launchEnvironment["YL_SKIP_HEALTH_AUTH"] = "1"
            app.launchEnvironment["YL_OPEN_TAB"] = tab
            app.launch()

            // 等待界面渲染完成
            let appeared = app.buttons.firstMatch.waitForExistence(timeout: 20)
                || app.staticTexts.firstMatch.waitForExistence(timeout: 20)
                || app.otherElements.firstMatch.waitForExistence(timeout: 20)
            _ = appeared
            Thread.sleep(forTimeInterval: 5)

            let screenshot = XCUIScreen.main.screenshot()
            let attachment = XCTAttachment(screenshot: screenshot)
            attachment.name = tab
            attachment.lifetime = .keepAlways
            add(attachment)

            app.terminate()
            Thread.sleep(forTimeInterval: 1)
        }
    }
}
