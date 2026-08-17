import XCTest
@testable import YL0veL

/// 管家模板回复测试（无 LLM 兜底路径）
final class ButlerTemplateReplyTests: XCTestCase {

    func testMorning() {
        let result = ButlerTemplateReply.reply(for: "早上好")
        XCTAssertEqual(result.reply, YPersona.Chat.morning)
        XCTAssertEqual(result.scenario, .greetMorning)
    }

    func testNight() {
        let result = ButlerTemplateReply.reply(for: "晚安啦")
        XCTAssertEqual(result.scenario, .greetNight)
    }

    func testReport() {
        let result = ButlerTemplateReply.reply(for: "看看报告")
        XCTAssertEqual(result.scenario, .reportReady)
    }

    func testChecklist() {
        let result = ButlerTemplateReply.reply(for: "准备清单")
        XCTAssertEqual(result.scenario, .prepareList)
    }

    func testHugVariants() {
        for text in ["抱抱", "好难过", "肚子疼", "心痛", "想哭"] {
            XCTAssertEqual(ButlerTemplateReply.reply(for: text).scenario, .hug, "输入「\(text)」应命中抱抱模板")
        }
    }

    func testRecordHint() {
        let result = ButlerTemplateReply.reply(for: "怎么记录")
        XCTAssertEqual(result.reply, YPersona.Chat.recordHint)
        XCTAssertNil(result.scenario)
    }

    func testPraise() {
        let result = ButlerTemplateReply.reply(for: "谢谢管家")
        XCTAssertEqual(result.reply, YPersona.Chat.praise)
        XCTAssertEqual(result.scenario, .chatPraise)
    }

    func testFallbackGreeting() {
        let result = ButlerTemplateReply.reply(for: "随便聊聊")
        XCTAssertEqual(result.reply, YPersona.Chat.greeting)
        XCTAssertEqual(result.scenario, .chatHere)
    }
}
