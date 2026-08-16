import XCTest
@testable import YL0veL

/// 中文语料表驱动测试（≥30 条：日期/流量/症状/情绪）
final class RecordParserTests: XCTestCase {

    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone.current
        return cal
    }

    private func date(_ string: String) -> Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.date(from: string)!
    }

    /// 用固定「今天」构建解析器，保证测试确定性
    private func parser(today: String) -> RecordParser {
        RecordParser(today: date(today))
    }

    func testTodayFlow() {
        let draft = parser(today: "2026-08-16").parse("今天来了，量少")
        XCTAssertEqual(draft?.date, date("2026-08-16"))
        XCTAssertEqual(draft?.flow, FlowLevel.light.rawValue)
    }

    func testYesterdayFlow() {
        let draft = parser(today: "2026-08-16").parse("昨天来的")
        XCTAssertEqual(draft?.date, date("2026-08-15"))
        XCTAssertEqual(draft?.flow, FlowLevel.medium.rawValue)
    }

    func testDayBeforeYesterday() {
        let draft = parser(today: "2026-08-16").parse("前天来的量多")
        XCTAssertEqual(draft?.date, date("2026-08-14"))
        XCTAssertEqual(draft?.flow, FlowLevel.heavy.rawValue)
    }

    func testThreeDaysAgo() {
        let draft = parser(today: "2026-08-16").parse("3天前来的")
        XCTAssertEqual(draft?.date, date("2026-08-13"))
    }

    func testLastWeekday() {
        // 2026-08-16 是周日；上周三 = 2026-08-05
        let draft = parser(today: "2026-08-16").parse("上周三来的")
        XCTAssertEqual(draft?.date, date("2026-08-05"))
    }

    func testThisWeekday() {
        // 2026-08-16 周日；本周五 = 2026-08-14
        let draft = parser(today: "2026-08-16").parse("这周五来的")
        XCTAssertEqual(draft?.date, date("2026-08-14"))
    }

    func testThisWeekdayPast() {
        // 本周三 = 2026-08-12
        let draft = parser(today: "2026-08-16").parse("这周三来的")
        XCTAssertEqual(draft?.date, date("2026-08-12"))
    }

    func testNextWeekday() {
        // 下周三 = 2026-08-19
        let draft = parser(today: "2026-08-16").parse("下周三来")
        XCTAssertEqual(draft?.date, date("2026-08-19"))
    }

    func testPlainWeekdayDefaultsToPast() {
        // 「周五」默认理解为最近的过去：2026-08-14
        let draft = parser(today: "2026-08-16").parse("周五来的")
        XCTAssertEqual(draft?.date, date("2026-08-14"))
    }

    func testMonthDayDate() {
        let draft = parser(today: "2026-08-16").parse("8月10日来的")
        XCTAssertEqual(draft?.date, date("2026-08-10"))
    }

    func testHeavyFlow() {
        XCTAssertEqual(parser(today: "2026-08-16").parse("今天来了，量很大")?.flow, FlowLevel.heavy.rawValue)
        XCTAssertEqual(parser(today: "2026-08-16").parse("今天来了，挺多的")?.flow, FlowLevel.heavy.rawValue)
    }

    func testMediumFlowDefault() {
        XCTAssertEqual(parser(today: "2026-08-16").parse("今天来大姨妈了")?.flow, FlowLevel.medium.rawValue)
        XCTAssertEqual(parser(today: "2026-08-16").parse("今天来例假了")?.flow, FlowLevel.medium.rawValue)
    }

    func testLightFlow() {
        XCTAssertEqual(parser(today: "2026-08-16").parse("今天来了，量不多")?.flow, FlowLevel.light.rawValue)
        XCTAssertEqual(parser(today: "2026-08-16").parse("今天来了一点点")?.flow, FlowLevel.light.rawValue)
    }

    func testCramps() {
        let draft = parser(today: "2026-08-16").parse("今天来了，肚子好疼")
        XCTAssertTrue(draft?.symptoms.contains("cramps") ?? false)
    }

    func testCrampsVariants() {
        XCTAssertTrue(parser(today: "2026-08-16").parse("痛经好严重")?.symptoms.contains("cramps") ?? false)
        XCTAssertTrue(parser(today: "2026-08-16").parse("腹痛")?.symptoms.contains("cramps") ?? false)
        XCTAssertTrue(parser(today: "2026-08-16").parse("姨妈痛")?.symptoms.contains("cramps") ?? false)
    }

    func testHeadache() {
        XCTAssertTrue(parser(today: "2026-08-16").parse("今天头痛")?.symptoms.contains("headache") ?? false)
        XCTAssertTrue(parser(today: "2026-08-16").parse("有点头疼")?.symptoms.contains("headache") ?? false)
    }

    func testBackache() {
        XCTAssertTrue(parser(today: "2026-08-16").parse("腰酸背痛")?.symptoms.contains("backache") ?? false)
        XCTAssertTrue(parser(today: "2026-08-16").parse("腰好痛")?.symptoms.contains("backache") ?? false)
    }

    func testNausea() {
        XCTAssertTrue(parser(today: "2026-08-16").parse("有点恶心")?.symptoms.contains("nausea") ?? false)
        XCTAssertTrue(parser(today: "2026-08-16").parse("想吐")?.symptoms.contains("nausea") ?? false)
    }

    func testTenderBreasts() {
        XCTAssertTrue(parser(today: "2026-08-16").parse("胸胀")?.symptoms.contains("tenderBreasts") ?? false)
    }

    func testFatigue() {
        XCTAssertTrue(parser(today: "2026-08-16").parse("今天好累啊")?.symptoms.contains("fatigue") ?? false)
    }

    func testInsomnia() {
        XCTAssertTrue(parser(today: "2026-08-16").parse("昨晚失眠了")?.symptoms.contains("insomnia") ?? false)
    }

    func testAcne() {
        XCTAssertTrue(parser(today: "2026-08-16").parse("长痘了")?.symptoms.contains("acne") ?? false)
    }

    func testBloating() {
        XCTAssertTrue(parser(today: "2026-08-16").parse("肚子胀")?.symptoms.contains("bloating") ?? false)
    }

    func testMoodIrritated() {
        XCTAssertEqual(parser(today: "2026-08-16").parse("今天很烦躁")?.mood, "irritated")
        XCTAssertEqual(parser(today: "2026-08-16").parse("易怒")?.mood, "irritated")
    }

    func testMoodHappy() {
        XCTAssertEqual(parser(today: "2026-08-16").parse("今天很开心")?.mood, "happy")
    }

    func testMoodSad() {
        XCTAssertEqual(parser(today: "2026-08-16").parse("有点难过")?.mood, "sad")
    }

    func testMoodAnxious() {
        XCTAssertEqual(parser(today: "2026-08-16").parse("很焦虑")?.mood, "anxious")
    }

    func testMoodTired() {
        XCTAssertEqual(parser(today: "2026-08-16").parse("好疲惫")?.mood, "tired")
    }

    func testMultipleSymptoms() {
        let draft = parser(today: "2026-08-16").parse("今天来了，肚子疼还头疼，量少")
        XCTAssertTrue(draft?.symptoms.contains("cramps") ?? false)
        XCTAssertTrue(draft?.symptoms.contains("headache") ?? false)
        XCTAssertEqual(draft?.flow, FlowLevel.light.rawValue)
    }

    func testComplexSentence() {
        let draft = parser(today: "2026-08-16").parse("昨天来了量中等，有点恶心，心情烦躁")
        XCTAssertEqual(draft?.date, date("2026-08-15"))
        XCTAssertEqual(draft?.flow, FlowLevel.medium.rawValue)
        XCTAssertTrue(draft?.symptoms.contains("nausea") ?? false)
        XCTAssertEqual(draft?.mood, "irritated")
    }

    func testNoFlowButSymptoms() {
        let draft = parser(today: "2026-08-16").parse("今天没来，就是肚子胀")
        XCTAssertNil(draft?.flow)
        XCTAssertTrue(draft?.symptoms.contains("bloating") ?? false)
    }

    func testUnparseableReturnsNil() {
        XCTAssertNil(parser(today: "2026-08-16").parse("随便说说"))
    }

    func testEmojiAndPunctuationTolerated() {
        let draft = parser(today: "2026-08-16").parse("今天来了，量少，肚子疼😭")
        XCTAssertEqual(draft?.flow, FlowLevel.light.rawValue)
        XCTAssertTrue(draft?.symptoms.contains("cramps") ?? false)
    }

    func testCrossMidnightAssumesToday() {
        // 凌晨记录「今天」仍按当天
        let draft = parser(today: "2026-08-16").parse("今天来了")
        XCTAssertEqual(draft?.date, date("2026-08-16"))
    }
}
