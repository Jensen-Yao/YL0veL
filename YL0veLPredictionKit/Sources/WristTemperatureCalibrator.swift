import Foundation

/// 手腕温度样本（每晚睡眠会话一个，℃）
public struct WristTemperatureSample: Equatable {
    public let date: Date
    public let value: Double

    public init(date: Date, value: Double) {
        self.date = date
        self.value = value
    }
}

/// 手腕温度相位校准器（对标 Apple 官方「回顾性排卵估算」机制与 Curry 2025 评估口径）
///
/// 原理：排卵后黄体期孕酮升高使核心体温上升约 0.3–0.5 ℃，夜间手腕温度随之升高。
/// 通过「基线 + 持续升温」判定黄体期，用于收窄下次经期预测窗口。
///
/// 自适应：无温度传感器（SE 1/2）或样本不足时，本校准器返回未建立基线，调用方自动降级。
public enum WristTemperatureCalibrator {
    /// Apple Watch 建立温度基线所需睡眠夜晚数（Apple 官方约 5 晚）
    public static let baselineNightsRequired = 5
    /// 黄体期升温阈值（℃）
    public static let lutealShiftThreshold = 0.3
    /// 判定黄体期所需连续升温夜晚数
    public static let lutealConsecutiveNights = 3

    public struct Analysis: Equatable {
        public let baselineEstablished: Bool
        /// 基线温度（前 N 晚均值）
        public let baseline: Double?
        /// 最近一晚相对基线的偏离（℃）
        public let latestDeviation: Double?
        /// 是否判定处于黄体期（已排卵）
        public let inLutealPhase: Bool
        /// 用于解释判定的说明
        public let summary: String

        public init(baselineEstablished: Bool, baseline: Double?, latestDeviation: Double?, inLutealPhase: Bool, summary: String) {
            self.baselineEstablished = baselineEstablished
            self.baseline = baseline
            self.latestDeviation = latestDeviation
            self.inLutealPhase = inLutealPhase
            self.summary = summary
        }

        public static let notEnoughData = Analysis(
            baselineEstablished: false, baseline: nil, latestDeviation: nil, inLutealPhase: false,
            summary: "温度数据不足，需要连续佩戴睡眠约 5 晚建立基线"
        )
    }

    /// 分析手腕温度序列。
    /// - Parameter samples: 按日期升序的夜间温度样本
    /// - Returns: 相位分析结果；样本不足时返回 `.notEnoughData`
    public static func analyze(_ samples: [WristTemperatureSample]) -> Analysis {
        guard samples.count >= baselineNightsRequired else { return .notEnoughData }

        let baselineSamples = Array(samples.prefix(baselineNightsRequired))
        let baseline = baselineSamples.map(\.value).reduce(0, +) / Double(baselineSamples.count)

        let subsequent = Array(samples.dropFirst(baselineNightsRequired))
        let latestDeviation = samples.last.map { $0.value - baseline }

        let inLutealPhase = subsequent.count >= lutealConsecutiveNights
            && subsequent.suffix(lutealConsecutiveNights).allSatisfy { $0.value - baseline >= lutealShiftThreshold }

        let summary: String
        if inLutealPhase {
            summary = "手腕温度已连续 \(lutealConsecutiveNights) 晚高于基线 \(lutealShiftThreshold) ℃ 以上，判定为黄体期（已排卵）"
        } else {
            summary = "基线已建立，当前温度偏离 \(String(format: "%.2f", latestDeviation ?? 0)) ℃，未见黄体期升温"
        }

        return Analysis(
            baselineEstablished: true,
            baseline: baseline,
            latestDeviation: latestDeviation,
            inLutealPhase: inLutealPhase,
            summary: summary
        )
    }
}
