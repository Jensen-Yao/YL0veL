import XCTest
import SwiftData
@testable import YL0veL

final class CycleReportGeneratorTests: XCTestCase {

    @MainActor
    private func makeDays(_ tuples: [(date: Date, flow: Int, symptoms: [String], mood: String?)]) -> [CycleDay] {
        tuples.map {
            CycleDay(date: $0.date, flow: $0.flow, symptoms: $0.symptoms, mood: $0.mood)
        }
    }

    private func date(_ string: String) -> Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.date(from: string)!
    }

    @MainActor
    func testReportFields() {
        let cycleStart = date("2026-07-01")
        let cycleEnd = date("2026-07-28")
        let days = makeDays([
            (date("2026-07-01"), 2, ["cramps"], "irritated"),
            (date("2026-07-02"), 3, ["cramps", "headache"], "tired"),
            (date("2026-07-03"), 1, [], "calm"),
            (date("2026-07-04"), 1, [], "calm"),
            (date("2026-07-10"), 0, ["bloating"], "anxious"),
        ])

        let generator = CycleReportGenerator()
        let input = CycleReportGenerator.Input(
            cycleStart: cycleStart,
            cycleEnd: cycleEnd,
            cycleLength: 28,
            days: days,
            cycleStarts: [cycleStart, date("2026-06-03"), date("2026-05-05")],
            health: .init(averageHeartRate: 72, averageHRV: 45, averageSleepHours: 7.2, averageWristTemperatureDeviation: nil),
            previousReport: nil
        )
        let report = generator.generate(from: input)

        XCTAssertEqual(report.cycleLength, 28)
        XCTAssertEqual(report.periodLength, 4)
        XCTAssertEqual(report.flowDistribution["中等"], 1)
        XCTAssertEqual(report.flowDistribution["大量"], 1)
        XCTAssertEqual(report.flowDistribution["少量"], 2)
        XCTAssertEqual(report.symptomCounts["cramps"], 2)
        XCTAssertEqual(report.symptomCounts["headache"], 1)
        XCTAssertEqual(report.moodCounts["calm"], 2)
        XCTAssertEqual(report.averageHeartRate ?? 0, 72, accuracy: 0.1)
        XCTAssertEqual(report.regularityScore, 100, accuracy: 0.1) // 周期 28/28/29 规律
        XCTAssertFalse(report.careMessage.isEmpty)
        XCTAssertTrue(report.comparisonSummary.contains("第一份"))
    }

    @MainActor
    func testFirstReportComparisonMessage() {
        let generator = CycleReportGenerator()
        let input = CycleReportGenerator.Input(
            cycleStart: date("2026-07-01"),
            cycleEnd: date("2026-07-28"),
            cycleLength: 28,
            days: [],
            cycleStarts: [date("2026-07-01")],
            health: .init(),
            previousReport: nil
        )
        let report = generator.generate(from: input)
        XCTAssertTrue(report.comparisonSummary.contains("第一份"))
    }

    func testRegularityScoreBoundaries() {
        let generator = CycleReportGenerator()
        let calendar = Calendar.current

        // 规律：标准差 0 → 100
        let regular = [date("2026-07-01"), date("2026-06-03"), date("2026-05-06"), date("2026-04-08")]
        XCTAssertEqual(generator.regularityScore(cycleStarts: regular), 100)

        // 波动大：标准差 ≥5 → 30
        let irregular = [date("2026-07-01"), date("2026-06-10"), date("2026-05-01"), date("2026-03-20")]
        XCTAssertEqual(generator.regularityScore(cycleStarts: irregular), 30)

        // 数据不足
        XCTAssertEqual(generator.regularityScore(cycleStarts: [date("2026-07-01")]), 0)
        _ = calendar
    }

    @MainActor
    func testPreviousReportComparison() {
        let generator = CycleReportGenerator()
        let previous = CycleReport(
            cycleStartDate: date("2026-06-03"),
            cycleEndDate: date("2026-06-30"),
            cycleLength: 27,
            periodLength: 5,
            flowDistribution: [:],
            symptomCounts: ["cramps": 3],
            moodCounts: [:],
            averageHeartRate: nil,
            averageHRV: nil,
            averageSleepHours: nil,
            averageWristTemperatureDeviation: nil,
            regularityScore: 85,
            comparisonSummary: "",
            careMessage: "",
            title: ""
        )
        let input = CycleReportGenerator.Input(
            cycleStart: date("2026-07-01"),
            cycleEnd: date("2026-07-28"),
            cycleLength: 28,
            days: makeDays([(date("2026-07-01"), 2, [], nil)]),
            cycleStarts: [date("2026-07-01"), date("2026-06-03")],
            health: .init(),
            previousReport: previous
        )
        let report = generator.generate(from: input)
        XCTAssertTrue(report.comparisonSummary.contains("长 1 天"))
        XCTAssertTrue(report.comparisonSummary.contains("少 4 天")) // 经期 1 天 vs 5 天
    }
}
