import XCTest
@testable import YL0veLPredictionKit

final class PredictionEngineTests: XCTestCase {

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

    func testPredictReturnsNilWithoutEnoughCycles() {
        let engine = PredictionEngine(calendar: calendar)
        XCTAssertNil(engine.predict(cycleStarts: [date("2026-01-01"), date("2025-12-01")]))
    }

    func testPredictRegularCycles() {
        let engine = PredictionEngine(calendar: calendar)
        let starts = [
            date("2026-01-01"), date("2025-12-03"), date("2025-11-04"), date("2025-10-06"),
        ]
        let prediction = engine.predict(cycleStarts: starts)
        XCTAssertNotNil(prediction)
        XCTAssertEqual(prediction?.confidence, .high)
        XCTAssertNotNil(prediction?.estimatedOvulationWindow)
        XCTAssertEqual(prediction?.nextMensesWindow.count ?? 0, 3)
    }

    func testPredictIrregularCyclesLowConfidence() {
        let engine = PredictionEngine(calendar: calendar)
        let starts = [
            date("2026-01-01"), date("2025-12-10"), date("2025-11-08"), date("2025-09-25"),
        ]
        let prediction = engine.predict(cycleStarts: starts)
        XCTAssertNotNil(prediction)
        XCTAssertEqual(prediction?.confidence, .low)
    }

    func testLutealTemperatureUpgradesConfidenceAndBasis() {
        let engine = PredictionEngine(calendar: calendar)
        let starts = [
            date("2026-01-01"), date("2025-12-03"), date("2025-11-04"), date("2025-10-06"),
        ]
        // 构造 8 晚温度：5 晚基线 + 3 晚黄体期升温
        let base = date("2026-01-10")
        let values: [Double] = [36.5, 36.6, 36.4, 36.5, 36.6, 36.9, 37.0, 36.95]
        let samples = values.enumerated().map { index, value in
            WristTemperatureSample(date: calendar.date(byAdding: .day, value: index, to: base)!, value: value)
        }
        let prediction = engine.predict(cycleStarts: starts, wristTemperatures: samples)
        XCTAssertNotNil(prediction)
        XCTAssertEqual(prediction?.confidence, .high)
        XCTAssertTrue(prediction?.basis.contains("黄体期") ?? false)
    }
}
