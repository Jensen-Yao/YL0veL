import XCTest
@testable import YL0veLPredictionKit

final class WristTemperatureCalibratorTests: XCTestCase {

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

    private func samples(_ values: [Double], startingAt start: String) -> [WristTemperatureSample] {
        let startDate = date(start)
        return values.enumerated().map { index, value in
            WristTemperatureSample(date: calendar.date(byAdding: .day, value: index, to: startDate)!, value: value)
        }
    }

    func testNotEnoughSamples() {
        let result = WristTemperatureCalibrator.analyze(samples([36.5, 36.6, 36.4, 36.5], startingAt: "2026-01-01"))
        XCTAssertFalse(result.baselineEstablished)
        XCTAssertNil(result.baseline)
        XCTAssertFalse(result.inLutealPhase)
    }

    func testBaselineEstablishedNoLutealShift() {
        let result = WristTemperatureCalibrator.analyze(samples([36.5, 36.6, 36.4, 36.5, 36.6, 36.5, 36.4], startingAt: "2026-01-01"))
        XCTAssertTrue(result.baselineEstablished)
        XCTAssertNotNil(result.baseline)
        XCTAssertFalse(result.inLutealPhase)
    }

    func testLutealShiftDetected() {
        // 前 5 晚基线 ~36.5，随后连续 3+ 晚升高 ≥0.3 → 黄体期
        let values: [Double] = [36.5, 36.6, 36.4, 36.5, 36.6, 36.9, 37.0, 36.95]
        let result = WristTemperatureCalibrator.analyze(samples(values, startingAt: "2026-01-01"))
        XCTAssertTrue(result.baselineEstablished)
        XCTAssertTrue(result.inLutealPhase)
        XCTAssertNotNil(result.latestDeviation)
    }

    func testLutealShiftRequiresConsecutiveNights() {
        // 只有一晚升高，不足连续 3 晚 → 不判定黄体期
        let values: [Double] = [36.5, 36.6, 36.4, 36.5, 36.6, 37.0, 36.5, 36.6]
        let result = WristTemperatureCalibrator.analyze(samples(values, startingAt: "2026-01-01"))
        XCTAssertFalse(result.inLutealPhase)
    }

    func testShiftBelowThresholdNotDetected() {
        // 升高不足 0.3 ℃
        let values: [Double] = [36.5, 36.6, 36.4, 36.5, 36.6, 36.75, 36.8, 36.78]
        let result = WristTemperatureCalibrator.analyze(samples(values, startingAt: "2026-01-01"))
        XCTAssertFalse(result.inLutealPhase)
    }
}
