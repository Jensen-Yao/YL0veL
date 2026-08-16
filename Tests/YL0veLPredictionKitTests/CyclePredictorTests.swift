import XCTest
@testable import YL0veLPredictionKit

/// drip `test/get-predicted-menses.spec.js` 用例逐条翻译
final class CyclePredictorTests: XCTestCase {

    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }

    private func date(_ string: String) -> Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.date(from: string)!
    }

    private func dayStrings(_ dates: [Date]) -> [String] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return dates.map { formatter.string(from: $0) }
    }

    // drip 用例：cannot predict next menses
    func testNoBleedingDocumented_returnsEmpty() {
        let predictor = CyclePredictor(calendar: calendar, configuration: .init(maxCycleLength: 99, minCyclesForPrediction: 1))
        XCTAssertEqual(predictor.predictedMenses(cycleStarts: []), [])
    }

    func testSingleStart_noCompletedCycle_returnsEmpty() {
        let predictor = CyclePredictor(calendar: calendar, configuration: .init(maxCycleLength: 99, minCyclesForPrediction: 1))
        XCTAssertEqual(predictor.predictedMenses(cycleStarts: [date("2018-06-02")]), [])
    }

    func testBelowMinCyclesForPrediction_returnsEmpty() {
        // 两个周期开始日 → 只有 1 个完整周期长度；默认 minCyclesForPrediction = 3
        let predictor = CyclePredictor(calendar: calendar)
        let starts = [date("2018-06-01"), date("2018-05-01")]
        XCTAssertEqual(predictor.predictedMenses(cycleStarts: starts), [])
    }

    func testCycleTooLongIsExcluded_returnsEmpty() {
        // 周期长度 31、30 均超过 maxCycleLength = 2，剔除后不足 3 个
        let predictor = CyclePredictor(calendar: calendar, configuration: .init(maxCycleLength: 2, minCyclesForPrediction: 3))
        let starts = [date("2018-06-01"), date("2018-05-01"), date("2018-04-01")]
        XCTAssertEqual(predictor.predictedMenses(cycleStarts: starts), [])
    }

    // drip 用例：works
    func testOneCompletedCycle_minCyclesOne() {
        let predictor = CyclePredictor(calendar: calendar, configuration: .init(maxCycleLength: 99, minCyclesForPrediction: 1))
        let starts = [date("2018-07-15"), date("2018-07-01")]
        let result = predictor.predictedMenses(cycleStarts: starts)
        let expected: [[String]] = [
            ["2018-07-27", "2018-07-28", "2018-07-29", "2018-07-30", "2018-07-31"],
            ["2018-08-10", "2018-08-11", "2018-08-12", "2018-08-13", "2018-08-14"],
            ["2018-08-24", "2018-08-25", "2018-08-26", "2018-08-27", "2018-08-28"],
        ]
        XCTAssertEqual(result.count, 3)
        for (window, expectedWindow) in zip(result, expected) {
            XCTAssertEqual(dayStrings(window), expectedWindow)
        }
    }

    func testMultipleRegularCycles() {
        let predictor = CyclePredictor(calendar: calendar, configuration: .init(maxCycleLength: 99, minCyclesForPrediction: 1))
        let starts = [date("2018-08-02"), date("2018-07-02"), date("2018-06-01"), date("2018-05-01")]
        let result = predictor.predictedMenses(cycleStarts: starts)
        let expected: [[String]] = [
            ["2018-09-01", "2018-09-02", "2018-09-03"],
            ["2018-10-02", "2018-10-03", "2018-10-04"],
            ["2018-11-02", "2018-11-03", "2018-11-04"],
        ]
        XCTAssertEqual(result.count, 3)
        for (window, expectedWindow) in zip(result, expected) {
            XCTAssertEqual(dayStrings(window), expectedWindow)
        }
    }

    func testThreeCyclesSmallDeviation_narrowWindow() {
        let predictor = CyclePredictor(calendar: calendar)
        let starts = [date("2018-08-01"), date("2018-07-18"), date("2018-07-05"), date("2018-06-20")]
        let result = predictor.predictedMenses(cycleStarts: starts)
        let expected: [[String]] = [
            ["2018-08-14", "2018-08-15", "2018-08-16"],
            ["2018-08-28", "2018-08-29", "2018-08-30"],
            ["2018-09-11", "2018-09-12", "2018-09-13"],
        ]
        XCTAssertEqual(result.count, 3)
        for (window, expectedWindow) in zip(result, expected) {
            XCTAssertEqual(dayStrings(window), expectedWindow)
        }
    }

    func testThreeCyclesBigDeviation_wideWindow() {
        let predictor = CyclePredictor(calendar: calendar)
        let starts = [date("2018-08-01"), date("2018-07-14"), date("2018-07-04"), date("2018-06-20")]
        let result = predictor.predictedMenses(cycleStarts: starts)
        let expected: [[String]] = [
            ["2018-08-13", "2018-08-14", "2018-08-15", "2018-08-16", "2018-08-17"],
            ["2018-08-27", "2018-08-28", "2018-08-29", "2018-08-30", "2018-08-31"],
            ["2018-09-10", "2018-09-11", "2018-09-12", "2018-09-13", "2018-09-14"],
        ]
        XCTAssertEqual(result.count, 3)
        for (window, expectedWindow) in zip(result, expected) {
            XCTAssertEqual(dayStrings(window), expectedWindow)
        }
    }

    func testCyclesLongerThanMaxAreExcluded() {
        // 04-20 → 06-20 为 61 天 > max 50，剔除；其余三个周期与上例相同
        let predictor = CyclePredictor(calendar: calendar, configuration: .init(maxCycleLength: 50, minCyclesForPrediction: 3))
        let starts = [
            date("2018-08-01"), date("2018-07-14"), date("2018-07-04"), date("2018-06-20"), date("2018-04-20"),
        ]
        let result = predictor.predictedMenses(cycleStarts: starts)
        let expected: [[String]] = [
            ["2018-08-13", "2018-08-14", "2018-08-15", "2018-08-16", "2018-08-17"],
            ["2018-08-27", "2018-08-28", "2018-08-29", "2018-08-30", "2018-08-31"],
            ["2018-09-10", "2018-09-11", "2018-09-12", "2018-09-13", "2018-09-14"],
        ]
        XCTAssertEqual(result.count, 3)
        for (window, expectedWindow) in zip(result, expected) {
            XCTAssertEqual(dayStrings(window), expectedWindow)
        }
    }

    func testCycleLengthStats() {
        let predictor = CyclePredictor(calendar: calendar)
        let starts = [date("2018-08-01"), date("2018-07-14"), date("2018-07-04"), date("2018-06-20")]
        let stats = predictor.cycleLengthStats(cycleStarts: starts)
        XCTAssertNotNil(stats)
        XCTAssertEqual(stats?.minimum, 10)
        XCTAssertEqual(stats?.maximum, 18)
        XCTAssertEqual(stats?.mean ?? 0, 14.0, accuracy: 0.001)
        XCTAssertEqual(stats?.stdDeviation ?? 0, 4.0, accuracy: 0.001)
    }
}
