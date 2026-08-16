import Foundation

/// 正态分布（用于周期长度先验与贝叶斯更新）
public struct NormalDistribution: Equatable {
    public let mean: Double
    public let variance: Double

    public init(mean: Double, variance: Double) {
        self.mean = mean
        self.variance = variance
    }

    public var standardDeviation: Double { variance.squareRoot() }
}

/// 贝叶斯周期长度先验（Soumpasis et al. 2020, Human Reproduction Open——Natural Cycles 大数据人群周期分布）
/// 人群周期长度近似正态分布：均值约 29 天，标准差约 4 天。
/// 用户历史周期数少时，用「人群先验 + 用户样本」的正态-正态共轭更新得到更稳的后验均值。
public enum BayesianCyclePrior {
    /// 人群先验（均值 29 天，方差 16 天²）
    public static let populationPrior = NormalDistribution(mean: 29.0, variance: 16.0)

    /// 正态-正态共轭后验
    /// - Parameters:
    ///   - sampleMean: 用户周期长度样本均值
    ///   - sampleVariance: 用户周期长度样本方差（无偏）
    ///   - sampleCount: 样本数
    public static func posterior(
        prior: NormalDistribution = populationPrior,
        sampleMean: Double,
        sampleVariance: Double,
        sampleCount: Int
    ) -> NormalDistribution {
        guard sampleCount > 0 else { return prior }
        // 完全规律的样本（方差为 0）用极小方差近似，后验逼近样本均值而非退回先验
        let effectiveVariance = max(sampleVariance, 0.01)
        let invPrior = 1.0 / prior.variance
        let invSample = Double(sampleCount) / effectiveVariance
        let posteriorVariance = 1.0 / (invPrior + invSample)
        let posteriorMean = (prior.mean * invPrior + sampleMean * invSample) * posteriorVariance
        return NormalDistribution(mean: posteriorMean, variance: posteriorVariance)
    }

    /// 便捷方法：由用户周期长度数组直接得后验
    public static func posterior(forCycleLengths lengths: [Int], prior: NormalDistribution = populationPrior) -> NormalDistribution {
        guard let stats = CycleStatistics.stats(for: lengths), lengths.count > 1, let sd = stats.stdDeviation else {
            // 样本不足时给一个介于先验与单样本之间的保守结果
            if let first = lengths.first {
                return posterior(prior: prior, sampleMean: Double(first), sampleVariance: 16.0, sampleCount: 1)
            }
            return prior
        }
        return posterior(prior: prior, sampleMean: stats.mean, sampleVariance: sd * sd, sampleCount: lengths.count)
    }
}
