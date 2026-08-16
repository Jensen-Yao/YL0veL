import Foundation

/// 预测结果
public struct CyclePrediction: Equatable {
    public enum Confidence: String, Equatable {
        case low
        case medium
        case high
    }

    /// 下次经期预测窗口（日期升序）
    public let nextMensesWindow: [Date]
    /// 未来第 2、3 次经期预测窗口（可选，数据不足时为空）
    public let futureWindows: [[Date]]
    /// 置信度
    public let confidence: Confidence
    /// 预测依据说明（展示给用户，诚实透明）
    public let basis: String
    /// 排卵窗口估计（可选）
    public let estimatedOvulationWindow: [Date]?

    public init(
        nextMensesWindow: [Date],
        futureWindows: [[Date]],
        confidence: Confidence,
        basis: String,
        estimatedOvulationWindow: [Date]? = nil
    ) {
        self.nextMensesWindow = nextMensesWindow
        self.futureWindows = futureWindows
        self.confidence = confidence
        self.basis = basis
        self.estimatedOvulationWindow = estimatedOvulationWindow
    }
}

/// 预测引擎门面：组合各层算法（drip mean±σ → 黄体期规则 → 贝叶斯先验 → 温度校准）
public struct PredictionEngine {
    public struct Configuration {
        public var maxCycleLength: Int
        public var minCyclesForPrediction: Int
        public var lutealLength: Int

        public init(maxCycleLength: Int = 99, minCyclesForPrediction: Int = 3, lutealLength: Int = 14) {
            self.maxCycleLength = maxCycleLength
            self.minCyclesForPrediction = minCyclesForPrediction
            self.lutealLength = lutealLength
        }
    }

    public let configuration: Configuration
    private let calendar: Calendar

    public init(configuration: Configuration = Configuration(), calendar: Calendar = .current) {
        self.configuration = configuration
        self.calendar = calendar
    }

    /// 生成周期预测。
    /// - Parameters:
    ///   - cycleStarts: 历史周期开始日（含当前进行中的周期）
    ///   - wristTemperatures: 手腕温度样本（无传感器设备传空数组即自动降级）
    /// - Returns: 预测；数据不足返回 nil
    public func predict(cycleStarts: [Date], wristTemperatures: [WristTemperatureSample] = []) -> CyclePrediction? {
        let predictor = CyclePredictor(
            calendar: calendar,
            configuration: .init(
                maxCycleLength: configuration.maxCycleLength,
                minCyclesForPrediction: configuration.minCyclesForPrediction
            )
        )
        let windows = predictor.predictedMenses(cycleStarts: cycleStarts)
        guard let nextWindow = windows.first, !nextWindow.isEmpty else { return nil }

        var basis = "基于历史周期长度的统计预测（平均周期法）"
        var confidence = CyclePrediction.Confidence.medium

        // 周期规律性（σ 越小越稳）
        if let stats = predictor.cycleLengthStats(cycleStarts: cycleStarts), let sd = stats.stdDeviation {
            if sd < 1.5 {
                confidence = .high
                basis += "；你的周期非常规律（标准差 \(String(format: "%.1f", sd)) 天）"
            } else if sd >= 4 {
                confidence = .low
                basis += "；你的周期波动较大（标准差 \(String(format: "%.1f", sd)) 天），预测仅供参考"
            }
        }

        // 手腕温度校准（自适应：样本不足自动跳过）
        let temperatureAnalysis = WristTemperatureCalibrator.analyze(wristTemperatures)
        if temperatureAnalysis.inLutealPhase {
            confidence = .high
            basis = "手腕温度显示黄体期升温（已确认排卵），下次经期预计在排卵后约 \(configuration.lutealLength) 天"
        } else if temperatureAnalysis.baselineEstablished {
            basis += "；手腕温度基线已建立，未见黄体期升温"
        }

        // 排卵窗口估计：下次经期预测窗口中心 − 黄体期，±2 天
        var ovulationWindow: [Date]? = nil
        if !nextWindow.isEmpty {
            let center = nextWindow[nextWindow.count / 2]
            if let ovulationCenter = calendar.date(byAdding: .day, value: -configuration.lutealLength, to: center) {
                var window = [ovulationCenter]
                for offset in [-2, -1, 1, 2] {
                    if let d = calendar.date(byAdding: .day, value: offset, to: ovulationCenter) {
                        window.append(d)
                    }
                }
                window.sort()
                ovulationWindow = window
            }
        }

        return CyclePrediction(
            nextMensesWindow: nextWindow,
            futureWindows: Array(windows.dropFirst()),
            confidence: confidence,
            basis: basis,
            estimatedOvulationWindow: ovulationWindow
        )
    }
}
