import Foundation

/// 周期相位
public enum CyclePhase: String, Equatable, Sendable {
    case menstrual   // 经期
    case follicular  // 卵泡期
    case ovulation   // 排卵期
    case luteal      // 黄体期
}

/// 周期相位计算（基于领域共识：排卵 ≈ 周期长 − 黄体期 12–16 天）
public enum CyclePhaseCalculator {

    /// 由周期第几天推算相位
    /// - Parameters:
    ///   - cycleDay: 周期第几天（1 起）
    ///   - cycleLength: 平均周期长度
    ///   - periodLength: 平均经期持续天数
    ///   - lutealLength: 黄体期长度（默认 14）
    public static func phase(
        cycleDay: Int,
        cycleLength: Int,
        periodLength: Int,
        lutealLength: Int = 14
    ) -> CyclePhase {
        guard cycleDay > 0 else { return .follicular }
        if cycleDay <= periodLength {
            return .menstrual
        }
        let ovulationDay = max(cycleLength - lutealLength, periodLength + 1)
        if cycleDay >= ovulationDay - 2 && cycleDay <= ovulationDay + 1 {
            return .ovulation
        }
        if cycleDay > ovulationDay {
            return .luteal
        }
        return .follicular
    }

    /// 估算的排卵日（周期第几天）
    public static func estimatedOvulationDay(cycleLength: Int, lutealLength: Int = 14) -> Int {
        max(cycleLength - lutealLength, 1)
    }
}
