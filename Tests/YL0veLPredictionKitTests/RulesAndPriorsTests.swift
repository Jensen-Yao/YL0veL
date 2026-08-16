import XCTest
@testable import YL0veLPredictionKit

final class LutealPhaseRuleTests: XCTestCase {

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

    func testEstimatedOvulation() {
        // 周期开始 2026-01-01，周期 28 天，黄体期 14 天 → 排卵 ≈ 2026-01-15
        let ovulation = LutealPhaseRule.estimatedOvulationDate(cycleStart: date("2026-01-01"), cycleLength: 28, calendar: calendar)
        XCTAssertEqual(ovulation, date("2026-01-15"))
    }

    func testPredictedMensesAfterOvulation() {
        // 排卵 2026-01-15 + 14 天 → 2026-01-29
        let menses = LutealPhaseRule.predictedMensesStart(afterOvulation: date("2026-01-15"), calendar: calendar)
        XCTAssertEqual(menses, date("2026-01-29"))
    }

    func testBBTConfirmationThreeRisingDays() {
        XCTAssertTrue(LutealPhaseRule.hasConfirmedOvulation(bbtValues: [36.5, 36.9, 37.0, 36.95], baseline: 36.5))
    }

    func testBBTNotConfirmedWithDips() {
        XCTAssertFalse(LutealPhaseRule.hasConfirmedOvulation(bbtValues: [36.9, 36.4, 37.0], baseline: 36.5))
    }

    func testBBTRequiresEnoughDays() {
        XCTAssertFalse(LutealPhaseRule.hasConfirmedOvulation(bbtValues: [36.9, 37.0], baseline: 36.5))
    }
}

final class BayesianCyclePriorTests: XCTestCase {

    func testNoSampleReturnsPrior() {
        let posterior = BayesianCyclePrior.posterior(sampleMean: 0, sampleVariance: 0, sampleCount: 0)
        XCTAssertEqual(posterior.mean, 29.0, accuracy: 0.001)
    }

    func testPosteriorMovesTowardSample() {
        // 3 个周期均值 26 天 → 后验应在 26 与 29 之间，偏向样本
        let posterior = BayesianCyclePrior.posterior(forCycleLengths: [26, 27, 25])
        XCTAssertGreaterThan(posterior.mean, 26.0)
        XCTAssertLessThan(posterior.mean, 29.0)
        XCTAssertGreaterThan(posterior.standardDeviation, 0)
    }

    func testLargeSampleDominatesPrior() {
        let lengths = Array(repeating: 25, count: 100)
        let posterior = BayesianCyclePrior.posterior(forCycleLengths: lengths)
        XCTAssertEqual(posterior.mean, 25.0, accuracy: 0.05)
    }

    func testSingleSampleFallback() {
        let posterior = BayesianCyclePrior.posterior(forCycleLengths: [30])
        XCTAssertGreaterThan(posterior.mean, 29.0)
        XCTAssertLessThan(posterior.mean, 30.5)
    }
}

final class WMATests: XCTestCase {

    func testWeightedMeanRecentHeavier() {
        // 旧周期 28、28、28，最近 34 → WMA 应高于普通均值 29.5
        let wma = WMA.weightedMean([28, 28, 28, 34])
        XCTAssertNotNil(wma)
        XCTAssertGreaterThan(wma!, 29.5)
        XCTAssertEqual(wma!, 30.4, accuracy: 0.01)
    }

    func testEmptyReturnsNil() {
        XCTAssertNil(WMA.weightedMean([]))
    }

    func testSingleValue() {
        XCTAssertEqual(WMA.weightedMean([28]) ?? 0, 28.0, accuracy: 0.001)
    }
}
