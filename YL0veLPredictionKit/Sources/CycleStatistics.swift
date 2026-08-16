import Foundation

/// 周期长度统计量（移植自 drip `lib/cycle-length.js` 的 getCycleLengthStats）
public struct CycleLengthStats: Equatable {
    public let minimum: Int
    public let maximum: Int
    public let mean: Double
    public let median: Double
    public let stdDeviation: Double?
}

public enum CycleStatistics {
    /// 计算周期长度数组的 min/max/mean/median/无偏样本标准差
    public static func stats(for cycleLengths: [Int]) -> CycleLengthStats? {
        guard !cycleLengths.isEmpty else { return nil }
        let sorted = cycleLengths.sorted()
        let mean = Double(cycleLengths.reduce(0, +)) / Double(cycleLengths.count)

        let median: Double
        let mid = sorted.count / 2
        if sorted.count % 2 == 1 {
            median = Double(sorted[mid])
        } else {
            median = (Double(sorted[mid - 1]) + Double(sorted[mid])) / 2
        }

        var stdDeviation: Double?
        if cycleLengths.count > 1 {
            let sumOfSquares = cycleLengths.reduce(0.0) { acc, length in
                acc + pow(Double(length) - mean, 2)
            }
            stdDeviation = (sumOfSquares / Double(cycleLengths.count - 1)).squareRoot()
        }

        return CycleLengthStats(
            minimum: sorted[0],
            maximum: sorted[sorted.count - 1],
            mean: mean,
            median: median,
            stdDeviation: stdDeviation
        )
    }
}
