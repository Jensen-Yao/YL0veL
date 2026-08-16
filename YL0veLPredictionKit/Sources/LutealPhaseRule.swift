import Foundation

/// 黄体期规则（参考 Mensinator 与领域共识）
/// 领域共识：排卵日 ≈ 周期长度 − 黄体期（12–16 天相对稳定）；下次经期 ≈ 排卵日 + 14 天；
/// BBT（基础体温）持续升温 3 天确认排卵（WHO/症状-体温法规则）。
public enum LutealPhaseRule {
    public static let typicalLutealLengthRange = 12...16

    /// 由最近一次经期开始日与周期长度估计排卵日
    public static func estimatedOvulationDate(
        cycleStart: Date,
        cycleLength: Int,
        lutealLength: Int = 14,
        calendar: Calendar = .current
    ) -> Date? {
        calendar.date(byAdding: .day, value: cycleLength - lutealLength, to: calendar.startOfDay(for: cycleStart))
    }

    /// 由已确认的排卵日预测下次经期开始日
    public static func predictedMensesStart(
        afterOvulation ovulationDate: Date,
        lutealLength: Int = 14,
        calendar: Calendar = .current
    ) -> Date? {
        calendar.date(byAdding: .day, value: lutealLength, to: calendar.startOfDay(for: ovulationDate))
    }

    /// 基础体温是否满足「持续升温 3 天确认排卵」
    /// - Parameters:
    ///   - bbtValues: 每日基础体温（℃），按时间升序，取最后 `consecutiveDays` 个判断
    ///   - baseline: 卵泡期基线体温
    ///   - threshold: 升温阈值（默认 0.3 ℃，WHO 规则常见 0.2–0.3）
    public static func hasConfirmedOvulation(
        bbtValues: [Double],
        baseline: Double,
        threshold: Double = 0.3,
        consecutiveDays: Int = 3
    ) -> Bool {
        guard bbtValues.count >= consecutiveDays else { return false }
        return bbtValues.suffix(consecutiveDays).allSatisfy { $0 - baseline >= threshold }
    }
}
