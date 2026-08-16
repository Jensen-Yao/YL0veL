import Foundation
import YL0veLPredictionKit

/// 周期报告生成器：经期结束后聚合数据生成报告（App 内阅读）
struct CycleReportGenerator {

    struct HealthMetrics {
        var averageHeartRate: Double?
        var averageHRV: Double?
        var averageSleepHours: Double?
        var averageWristTemperatureDeviation: Double?
    }

    struct Input {
        var cycleStart: Date
        var cycleEnd: Date
        var cycleLength: Int
        var days: [CycleDay]
        var cycleStarts: [Date]          // 全部历史周期开始（用于规律性评分）
        var health: HealthMetrics
        var previousReport: CycleReport?
    }

    /// 生成报告
    func generate(from input: Input) -> CycleReport {
        let periodDays = input.days.filter { $0.date >= input.cycleStart && $0.date <= input.cycleEnd && $0.flow > 0 }
        let periodLength = periodDays.count

        // 流量分布
        var flowDistribution: [String: Int] = [:]
        for day in periodDays {
            let name = FlowLevel(rawValue: day.flow)?.displayName ?? "无"
            flowDistribution[name, default: 0] += 1
        }

        // 症状/情绪统计
        var symptomCounts: [String: Int] = [:]
        var moodCounts: [String: Int] = [:]
        for day in input.days where day.date >= input.cycleStart && day.date <= input.cycleEnd {
            for code in day.symptoms {
                symptomCounts[code, default: 0] += 1
            }
            if let mood = day.mood {
                moodCounts[mood, default: 0] += 1
            }
        }

        let score = regularityScore(cycleStarts: input.cycleStarts)
        let comparison = comparisonSummary(input: input, periodLength: periodLength, symptomCounts: symptomCounts)
        let care = careMessage(input: input, periodLength: periodLength, symptomCounts: symptomCounts, score: score)

        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日"
        let title = "\(formatter.string(from: input.cycleStart)) 起 · 第 \(input.cycleStarts.count) 个周期"

        return CycleReport(
            cycleStartDate: input.cycleStart,
            cycleEndDate: input.cycleEnd,
            cycleLength: input.cycleLength,
            periodLength: periodLength,
            flowDistribution: flowDistribution,
            symptomCounts: symptomCounts,
            moodCounts: moodCounts,
            averageHeartRate: input.health.averageHeartRate,
            averageHRV: input.health.averageHRV,
            averageSleepHours: input.health.averageSleepHours,
            averageWristTemperatureDeviation: input.health.averageWristTemperatureDeviation,
            regularityScore: score,
            comparisonSummary: comparison,
            careMessage: care,
            title: title
        )
    }

    // MARK: - 规律性评分（0–100，基于个人周期标准差）

    func regularityScore(cycleStarts: [Date]) -> Double {
        let predictor = CyclePredictor()
        guard let stats = predictor.cycleLengthStats(cycleStarts: cycleStarts) else { return 0 }
        guard let sd = stats.stdDeviation else { return 60 }
        switch sd {
        case ..<1: return 100
        case ..<2: return 85
        case ..<3: return 70
        case ..<4: return 55
        case ..<5: return 45
        default: return 30
        }
    }

    // MARK: - 对比摘要

    private func comparisonSummary(input: Input, periodLength: Int, symptomCounts: [String: Int]) -> String {
        guard let previous = input.previousReport else {
            return "这是你的第一份周期报告，之后每次经期结束都会生成一份，见证身体的变化规律 💗"
        }
        let lengthDelta = input.cycleLength - previous.cycleLength
        let periodDelta = periodLength - previous.periodLength
        var parts: [String] = []
        if lengthDelta == 0 {
            parts.append("周期长度与上次一致（\(input.cycleLength) 天）")
        } else if lengthDelta > 0 {
            parts.append("周期比上次长 \(lengthDelta) 天")
        } else {
            parts.append("周期比上次短 \(-lengthDelta) 天")
        }
        if periodDelta != 0 {
            parts.append(periodDelta > 0 ? "经期比上次多 \(periodDelta) 天" : "经期比上次少 \(-periodDelta) 天")
        }
        let crampDays = symptomCounts["cramps"] ?? 0
        let previousCrampDays = previous.symptomCounts["cramps"] ?? 0
        if crampDays != previousCrampDays {
            parts.append(crampDays > previousCrampDays ? "痛经天数比上次多" : "痛经天数比上次少")
        } else if crampDays > 0 {
            parts.append("痛经天数与上次相同")
        }
        return parts.joined(separator: "；") + "。"
    }

    // MARK: - 关怀文案（内置模板库；配 LLM 后由 LLM 生成更个性化版本）

    private func careMessage(input: Input, periodLength: Int, symptomCounts: [String: Int], score: Double) -> String {
        let crampDays = symptomCounts["cramps"] ?? 0
        let hasPain = crampDays > 0
        let headacheDays = symptomCounts["headache"] ?? 0

        if score >= 85 && !hasPain {
            return "这个周期非常规律，身体状态很棒！继续保持规律作息，多喝温水 🌸"
        }
        if hasPain && headacheDays > 0 {
            return "这个周期辛苦了，痛经 \(crampDays) 天、头痛 \(headacheDays) 天。下次经期前一周可以试试热敷、早睡和适度散步，我会提前提醒你 💗"
        }
        if hasPain {
            return "这个周期有 \(crampDays) 天痛经，抱抱你。经期前减少冰饮和咖啡会舒服一些，我会提前提醒你的 🫶"
        }
        if score < 55 {
            return "周期最近有点波动，不用太担心，压力、作息都会影响它。继续记录，我会越来越懂你 💗"
        }
        return "记录得很完整，真棒！继续保持，我会陪你一起守护健康 ✨"
    }
}
