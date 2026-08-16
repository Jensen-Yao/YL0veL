import XCTest

/// 模拟器截图测试：依次以不同 Tab 启动 App 并截屏（附件导出后作为文档截图）
final class ScreenshotTests: XCTestCase {

    override func setUp() {
        continueAfterFailure = true
        // 自动处理系统弹窗（HealthKit 授权等）
        addUIInterruptionMonitor(withDescription: "System Alerts") { alert in
            let allow = alert.buttons["Allow"]
            let turnOnAll = alert.buttons["Turn On All"]
            let ok = alert.buttons["OK"]
            if allow.exists {
                allow.tap()
                return true
            }
            if turnOnAll.exists {
                turnOnAll.tap()
                return true
            }
            if ok.exists {
                ok.tap()
                return true
            }
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
            app.launchEnvironment["YL_OPEN_TAB"] = tab
            app.launch()

            // 轮询等待并处理 HealthKit 授权等系统弹窗（最长 12 秒）
            for _ in 0..<6 {
                Thread.sleep(forTimeInterval: 2)
                let turnOnAll = springboard.buttons["Turn On All"]
                let allow = springboard.buttons["Allow"]
                let ok = springboard.buttons["OK"]
                if turnOnAll.exists {
                    turnOnAll.tap()
                    break
                }
                if allow.exists {
                    allow.tap()
                    break
                }
                if ok.exists {
                    ok.tap()
                    break
                }
            }

            // 等待界面渲染
            _ = app.buttons.firstMatch.waitForExistence(timeout: 15)
                || app.staticTexts.firstMatch.waitForExistence(timeout: 15)
            Thread.sleep(forTimeInterval: 6)

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
