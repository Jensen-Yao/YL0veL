import Foundation

/// 加权移动平均（WMA，参考 vani-cycle 的策略）：最近周期权重最高，对趋势更敏感
public enum WMA {
    /// - Parameter values: 按时间升序（最旧在前）
    /// - Returns: 加权平均；空数组返回 nil
    public static func weightedMean(_ values: [Int]) -> Double? {
        guard !values.isEmpty else { return nil }
        let weights = (1...values.count).map(Double.init)
        let totalWeight = weights.reduce(0, +)
        let weightedSum = zip(values, weights).reduce(0.0) { acc, pair in
            acc + Double(pair.0) * pair.1
        }
        return weightedSum / totalWeight
    }

    /// 按时间升序排列的周期长度（最旧在前）→ 加权平均
    public static func weightedMeanOfCycleLengths(ascendingLengths: [Int]) -> Double? {
        weightedMean(ascendingLengths)
    }
}
