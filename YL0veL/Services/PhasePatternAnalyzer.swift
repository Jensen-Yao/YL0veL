import Foundation
import YL0veLPredictionKit

/// 周期相位模式分析：黄体期 vs 卵泡期的情绪/症状差异（发现身体规律，温柔提示）
enum PhasePatternAnalyzer {

    struct Result: Equatable {
        /// 黄体期主导的负面情绪（nil = 无显著模式）
        var lutealDominantMood: String?
        /// 黄体期负面情绪占比
        var lutealRatio: Double
        /// 卵泡期负面情绪占比
        var follicularRatio: Double
        /// 分析的完整周期数
        var cyclesAnalyzed: Int
    }

    /// 负面情绪组（用于模式检测）
    static let negativeMoods: Set<String> = ["tired", "irritated", "anxious"]

    /// 分析近 3 个完整周期的黄体期 vs 卵泡期负面情绪占比
    static func analyze(
        cycleDays: [CycleDay],
        cycleStarts: [Date],
        cycleLength: Int,
        periodLength: Int,
        lutealLength: Int = 14
    ) -> Result? {
        let starts = cycleStarts.map { Calendar.current.startOfDay(for: $0) }.sorted(by: >)
        guard starts.count >= 2 else { return nil }

        let calendar = Calendar.current
        let ovulationDay = max(cycleLength - lutealLength, periodLength + 1)
        var lutealTotal = 0
        var lutealNegative = 0
        var follicularTotal = 0
        var follicularNegative = 0
        var cyclesAnalyzed = 0

        for index in 1..<min(starts.count, 4) {
            let cycleStart = starts[index]
            let cycleEnd = calendar.date(byAdding: .day, value: -1, to: starts[index - 1])!
            cyclesAnalyzed += 1

            for day in cycleDays where day.date >= cycleStart && day.date <= cycleEnd {
                guard let mood = day.mood else { continue }
                let dayNumber = (calendar.dateComponents([.day], from: cycleStart, to: day.date).day ?? 0) + 1
                let isNegative = negativeMoods.contains(mood)
                if dayNumber > ovulationDay {
                    lutealTotal += 1
                    if isNegative { lutealNegative += 1 }
                } else if dayNumber > periodLength && dayNumber < ovulationDay - 2 {
                    follicularTotal += 1
                    if isNegative { follicularNegative += 1 }
                }
            }
        }

        guard lutealTotal >= 3, follicularTotal >= 3 else { return nil }
        let lutealRatio = Double(lutealNegative) / Double(lutealTotal)
        let follicularRatio = Double(follicularNegative) / Double(follicularTotal)

        var dominant: String? = nil
        if lutealRatio > follicularRatio + 0.25 {
            dominant = "luteal"
        }
        return Result(
            lutealDominantMood: dominant,
            lutealRatio: lutealRatio,
            follicularRatio: follicularRatio,
            cyclesAnalyzed: cyclesAnalyzed
        )
    }
}
