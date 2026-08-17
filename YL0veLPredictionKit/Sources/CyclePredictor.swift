import Foundation

/// 基于历史周期长度的经期预测（移植自 drip `lib/cycle.js` 的 getPredictedMenses）
///
/// 算法（与 drip 一致）：
/// 1. 需要至少 `minCyclesForPrediction` 个有效周期（默认 3）
/// 2. 周期长度超过 `maxCycleLength`（默认 99 天）的异常周期被剔除
/// 3. 预测距离 = round(mean)；标准差 < 1.5 → 预测窗口 ±1 天，否则 ±2 天（无标准差时 ±2 天）
/// 4. 输出未来 `futurePredictionCount`（默认 3）次经期的预测窗口
public struct CyclePredictor {
    public struct Configuration {
        public var maxCycleLength: Int
        public var minCyclesForPrediction: Int
        public var futurePredictionCount: Int

        public init(maxCycleLength: Int = 99, minCyclesForPrediction: Int = 3, futurePredictionCount: Int = 3) {
            self.maxCycleLength = maxCycleLength
            self.minCyclesForPrediction = minCyclesForPrediction
            self.futurePredictionCount = futurePredictionCount
        }
    }

    private let calendar: Calendar
    private let configuration: Configuration

    public init(calendar: Calendar = .current, configuration: Configuration = Configuration()) {
        self.calendar = calendar
        self.configuration = configuration
    }

    /// 预测未来几次经期的开始日窗口。
    /// - Parameter cycleStarts: 每个周期的开始日（当前进行中的周期可作为最新一项传入），顺序不限。
    /// - Returns: 预测窗口数组（每次经期一个窗口，窗口内日期升序）；数据不足时返回空数组。
    public func predictedMenses(cycleStarts: [Date]) -> [[Date]] {
        let starts = normalizedStarts(cycleStarts)
        let cycleLengths = validCycleLengths(starts)
        guard cycleLengths.count >= configuration.minCyclesForPrediction,
              let stats = CycleStatistics.stats(for: cycleLengths) else {
            return []
        }

        let periodDistance = Int(stats.mean.rounded())
        let periodStartVariation: Int
        if let sd = stats.stdDeviation {
            periodStartVariation = sd < 1.5 ? 1 : 2
        } else {
            periodStartVariation = 2
        }

        // 预测区间过窄会重叠时放弃预测（与 drip 一致）
        guard periodDistance - 5 >= periodStartVariation else { return [] }

        var lastStart = starts[0]
        var result: [[Date]] = []
        for _ in 0..<configuration.futurePredictionCount {
            guard let center = calendar.date(byAdding: .day, value: periodDistance, to: lastStart) else { break }
            var window = [center]
            for j in 0..<periodStartVariation {
                if let before = calendar.date(byAdding: .day, value: -(j + 1), to: center) {
                    window.append(before)
                }
                if let after = calendar.date(byAdding: .day, value: j + 1, to: center) {
                    window.append(after)
                }
            }
            window.sort()
            result.append(window)
            lastStart = center
        }
        return result
    }

    /// 周期长度统计（供 UI 展示：平均周期、规律性等）
    public func cycleLengthStats(cycleStarts: [Date]) -> CycleLengthStats? {
        let lengths = validCycleLengths(normalizedStarts(cycleStarts))
        return CycleStatistics.stats(for: lengths)
    }

    /// 完整周期长度（升序，旧 → 新），供 WMA/贝叶斯先验使用
    public func cycleLengthsAscending(cycleStarts: [Date]) -> [Int] {
        Array(validCycleLengths(normalizedStarts(cycleStarts)).reversed())
    }

    /// 由指定周期距离与窗口宽度生成预测窗口（供 PredictionEngine 的贝叶斯/WMA 分支复用）
    public func predictedWindows(lastStart: Date, periodDistance: Int, variation: Int, count: Int = 3) -> [[Date]] {
        var result: [[Date]] = []
        var current = lastStart
        for _ in 0..<count {
            guard let center = calendar.date(byAdding: .day, value: periodDistance, to: current) else { break }
            var window = [center]
            for j in 0..<variation {
                if let before = calendar.date(byAdding: .day, value: -(j + 1), to: center) {
                    window.append(before)
                }
                if let after = calendar.date(byAdding: .day, value: j + 1, to: center) {
                    window.append(after)
                }
            }
            window.sort()
            result.append(window)
            current = center
        }
        return result
    }

    // MARK: - Private

    /// 归一化为「当天零点、最新在前」
    private func normalizedStarts(_ starts: [Date]) -> [Date] {
        starts
            .map { calendar.startOfDay(for: $0) }
            .sorted(by: >)
    }

    /// 相邻周期开始日差值作为周期长度，剔除无效与超长周期
    private func validCycleLengths(_ sortedDescendingStarts: [Date]) -> [Int] {
        guard sortedDescendingStarts.count > 1 else { return [] }
        var lengths: [Int] = []
        for i in 0..<(sortedDescendingStarts.count - 1) {
            let days = calendar.dateComponents([.day], from: sortedDescendingStarts[i + 1], to: sortedDescendingStarts[i]).day ?? 0
            if days > 0 && days <= configuration.maxCycleLength {
                lengths.append(days)
            }
        }
        return lengths
    }
}
