import XCTest

/// 模拟器截图测试：依次以不同 Tab 启动 App 并截屏
/// 截图 PNG 写入 UI test runner 的 Documents 目录（tab 名命名），由 CI 拷贝回仓库
final class ScreenshotTests: XCTestCase {

    override func setUp() {
        continueAfterFailure = true
        addUIInterruptionMonitor(withDescription: "System Alerts") { alert in
            let allow = alert.buttons["Allow"]
            let turnOnAll = alert.buttons["Turn On All"]
            let ok = alert.buttons["OK"]
            if allow.exists { allow.tap(); return true }
            if turnOnAll.exists { turnOnAll.tap(); return true }
            if ok.exists { ok.tap(); return true }
            return false
        }
    }

    func testCaptureAllTabs() throws {
        let app = XCUIApplication()
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")

        for tab in ["calendar", "insights", "report", "settings", "voice"] {
            app.launchEnvironment["YL_SKIP_DISCLAIMER"] = "1"
            app.launchEnvironment["YL_SEED_DEMO"] = "1"
            app.launchEnvironment["YL_SKIP_HEALTH_AUTH"] = "1"
            app.launchEnvironment["YL_OPEN_TAB"] = tab == "voice" ? "calendar" : tab
            app.launch()

            // 轮询处理系统弹窗（最长 12 秒）
            for _ in 0..<6 {
                Thread.sleep(forTimeInterval: 2)
                let turnOnAll = springboard.buttons["Turn On All"]
                let allow = springboard.buttons["Allow"]
                let ok = springboard.buttons["OK"]
                if turnOnAll.exists { turnOnAll.tap(); break }
                if allow.exists { allow.tap(); break }
                if ok.exists { ok.tap(); break }
            }

            // 等待界面渲染
            _ = app.buttons.firstMatch.waitForExistence(timeout: 15)
                || app.staticTexts.firstMatch.waitForExistence(timeout: 15)
            Thread.sleep(forTimeInterval: 4)

            // voice 轮：点击日历页的「语音记录」按钮打开语音输入界面
            if tab == "voice" {
                let voiceButton = app.buttons.matching(
                    NSPredicate(format: "label CONTAINS %@", "语音记录")
                ).firstMatch
                if voiceButton.waitForExistence(timeout: 8) {
                    voiceButton.tap()
                    Thread.sleep(forTimeInterval: 4)
                }
            }

            let screenshot = XCUIScreen.main.screenshot()
            // 写文件到 runner 沙盒（CI 拷贝回仓库，规范命名）
            if let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                try? screenshot.pngRepresentation.write(to: docs.appendingPathComponent("\(tab).png"))
            }
            // 同时保留 attachment 作为备选
            let attachment = XCTAttachment(screenshot: screenshot)
            attachment.name = tab
            attachment.lifetime = .keepAlways
            add(attachment)

            app.terminate()
            Thread.sleep(forTimeInterval: 1)
        }
    }
}
