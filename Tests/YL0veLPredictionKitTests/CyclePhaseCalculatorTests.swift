import XCTest
@testable import YL0veLPredictionKit

/// CyclePhaseCalculator 边界测试（各相位：经期/卵泡期/排卵期/黄体期）
final class CyclePhaseCalculatorTests: XCTestCase {

    func testMenstrualPhase() {
        // 周期第 1~5 天（经期长 5 天）
        for day in 1...5 {
            XCTAssertEqual(
                CyclePhaseCalculator.phase(cycleDay: day, cycleLength: 28, periodLength: 5),
                .menstrual,
                "第 \(day) 天应为经期"
            )
        }
    }

    func testFollicularPhase() {
        // 经期结束到排卵窗口前（排卵 ≈ 28-14 = 第 14 天，窗口 12~15）
        for day in 6...11 {
            XCTAssertEqual(
                CyclePhaseCalculator.phase(cycleDay: day, cycleLength: 28, periodLength: 5),
                .follicular,
                "第 \(day) 天应为卵泡期"
            )
        }
    }

    func testOvulationPhase() {
        // 排卵窗口：ovulationDay-2 ~ ovulationDay+1（第 12~15 天）
        for day in 12...15 {
            XCTAssertEqual(
                CyclePhaseCalculator.phase(cycleDay: day, cycleLength: 28, periodLength: 5),
                .ovulation,
                "第 \(day) 天应为排卵期"
            )
        }
    }

    func testLutealPhase() {
        // 排卵后到周期结束（第 16~28 天）
        for day in 16...28 {
            XCTAssertEqual(
                CyclePhaseCalculator.phase(cycleDay: day, cycleLength: 28, periodLength: 5),
                .luteal,
                "第 \(day) 天应为黄体期"
            )
        }
    }

    func testEstimatedOvulationDay() {
        XCTAssertEqual(CyclePhaseCalculator.estimatedOvulationDay(cycleLength: 28), 14)
        XCTAssertEqual(CyclePhaseCalculator.estimatedOvulationDay(cycleLength: 30), 16)
        XCTAssertEqual(CyclePhaseCalculator.estimatedOvulationDay(cycleLength: 21), 7)
    }

    func testInvalidCycleDay() {
        // 非法输入：第 0 天回退卵泡期（防御行为）
        XCTAssertEqual(CyclePhaseCalculator.phase(cycleDay: 0, cycleLength: 28, periodLength: 5), .follicular)
    }

    func testShortCycleWithLongPeriod() {
        // 周期 21 天、经期 7 天：排卵日 ≈ 7，经期直接进入排卵窗口
        XCTAssertEqual(CyclePhaseCalculator.phase(cycleDay: 6, cycleLength: 21, periodLength: 7), .menstrual)
        XCTAssertEqual(CyclePhaseCalculator.phase(cycleDay: 8, cycleLength: 21, periodLength: 7), .ovulation)
    }
}
