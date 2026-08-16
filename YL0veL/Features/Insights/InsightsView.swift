import SwiftUI
import SwiftData
import Charts
import HealthKit
import YL0veLPredictionKit

/// 洞察：心率/HRV/睡眠与周期叠加 + 手腕温度（自适应：无传感器/无数据自动降级）
struct InsightsView: View {
    @EnvironmentObject private var cycleStore: CycleStore
    @EnvironmentObject private var healthKit: HealthKitService

    @State private var heartRateSamples: [(date: Date, value: Double)] = []
    @State private var hrvSamples: [(date: Date, value: Double)] = []
    @State private var sleepHours: [(date: Date, value: Double)] = []
    @State private var wristTemperatures: [WristTemperatureSample] = []
    @State private var temperatureAnalysis: WristTemperatureCalibrator.Analysis?
    @State private var loading = true
    @State private var lastRefreshed: Date = .now

    private var range: ClosedRange<Date> {
        let end = Calendar.current.startOfDay(for: .now)
        let start = Calendar.current.date(byAdding: .day, value: -28, to: end)!
        return start...end
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if loading {
                        ProgressView("正在读取健康数据…")
                            .padding(.top, 60)
                    } else {
                        // 趋势与预警（本地数据，无需授权）
                        trendCard

                        // 温度卡（自适应：无数据时显示降级说明）
                        temperatureCard

                        // 心率趋势
                        metricChartCard(
                            title: "静息心率",
                            unit: "次/分",
                            samples: heartRateSamples,
                            color: .red
                        )

                        // HRV
                        metricChartCard(
                            title: "心率变异性 (HRV)",
                            unit: "ms",
                            samples: hrvSamples,
                            color: .green
                        )

                        // 睡眠
                        metricChartCard(
                            title: "睡眠时长",
                            unit: "小时",
                            samples: sleepHours,
                            color: .indigo
                        )

                        Text("以上信号随周期相位自然波动（黄体期心率略升、HRV 略降），仅作趋势参考，不参与预测计算。")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal)
                    }
                }
                .padding()
            }
            .background(YLTheme.softBackground)
            .navigationTitle("洞察")
            .refreshable {
                await loadData()
            }
            .task {
                await loadData()
            }
        }
    }

    // MARK: - 趋势与预警卡（本地数据）

    /// 周期长度序列（旧 → 新）
    private var cycleLengthTrend: [Int] {
        let starts = cycleStore.cycleStarts()
        guard starts.count >= 2 else { return [] }
        var lengths: [Int] = []
        for index in 1..<starts.count {
            if let days = Calendar.current.dateComponents([.day], from: starts[index], to: starts[index - 1]).day {
                lengths.append(days)
            }
        }
        return lengths.reversed()
    }

    /// 每个完整周期的痛经天数（旧 → 新）
    private var crampTrend: [Int] {
        let starts = cycleStore.cycleStarts()
        var result: [Int] = []
        for index in 1..<starts.count {
            let start = starts[index]
            let end = starts[index - 1]
            let days = cycleStore.cycleDays
                .filter { $0.date >= start && $0.date < end && $0.symptoms.contains("cramps") }
                .count
            result.append(days)
        }
        return result.reversed()
    }

    private var crampsWorsening: Bool {
        let recent = crampTrend.suffix(3)
        return recent.count == 3
            && recent[recent.index(recent.startIndex, offsetBy: 0)] < recent[recent.index(recent.startIndex, offsetBy: 1)]
            && recent[recent.index(recent.startIndex, offsetBy: 1)] < recent[recent.index(recent.startIndex, offsetBy: 2)]
            && recent.last! > 0
    }

    @ViewBuilder
    private var trendCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("周期趋势")
                .font(.headline)

            if cycleLengthTrend.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "info.circle")
                    Text("多记录几个周期，管家 Y 就能看出你的规律啦 🌱")
                        .font(.footnote)
                }
                .foregroundStyle(.secondary)
            } else {
                Chart(Array(cycleLengthTrend.enumerated()), id: \.offset) { index, length in
                    BarMark(
                        x: .value("周期", "第\(index + 1)个"),
                        y: .value("天数", length)
                    )
                    .foregroundStyle(YLTheme.primary.opacity(0.7))
                    .cornerRadius(4)
                }
                .frame(height: 110)
                .chartYAxisLabel("天")
                .chartXAxisLabel("周期（旧 → 新）")
            }

            // 痛经预警
            if crampsWorsening {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "exclamationmark.heart.fill")
                        .foregroundStyle(.orange)
                    Text(YPersona.Alert.crampsWorsening(cycles: 3))
                        .font(.footnote)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
                .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .ylCard()
    }

    // MARK: - 温度卡

    @ViewBuilder
    private var temperatureCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "thermometer.medium")
                    .foregroundStyle(.orange)
                Text("手腕温度")
                    .font(.headline)
                Spacer()
            }

            if let analysis = temperatureAnalysis, analysis.baselineEstablished {
                if !wristTemperatures.isEmpty {
                    Chart(wristTemperatures, id: \.date) { sample in
                        LineMark(
                            x: .value("日期", sample.date),
                            y: .value("温度", sample.value)
                        )
                        .foregroundStyle(.orange)
                        PointMark(
                            x: .value("日期", sample.date),
                            y: .value("温度", sample.value)
                        )
                        .foregroundStyle(analysis.inLutealPhase ? .orange : .secondary)
                        .symbolSize(24)
                    }
                    .frame(height: 120)
                }
                Text(analysis.summary)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                if analysis.inLutealPhase {
                    Label("黄体期（已排卵）", systemImage: "checkmark.seal.fill")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.orange)
                }
            } else {
                HStack(spacing: 10) {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.secondary)
                    Text(temperatureEmptyText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 6)
            }
        }
        .ylCard()
    }

    private var temperatureEmptyText: String {
        YPersona.Empty.noTemperature
    }

    // MARK: - 指标图

    @ViewBuilder
    private func metricChartCard(title: String, unit: String, samples: [(date: Date, value: Double)], color: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)

            if samples.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "info.circle")
                    Text(YPersona.Empty.noHealthData)
                        .font(.footnote)
                }
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 6)
            } else {
                Chart(samples, id: \.date) { sample in
                    LineMark(
                        x: .value("日期", sample.date),
                        y: .value("值", sample.value)
                    )
                    .foregroundStyle(color)
                    .interpolationMethod(.monotone)
                }
                .frame(height: 100)
                .chartYAxisLabel(unit)
            }
        }
        .ylCard()
    }

    // MARK: - 数据加载

    private func loadData() async {
        guard !loading || heartRateSamples.isEmpty else { return }
        loading = true
        let start = range.lowerBound
        let end = range.upperBound

        if healthKit.isAuthorized {
            if let samples = try? await healthKit.fetchHeartRateSamples(from: start, to: end) {
                heartRateSamples = dailyAggregate(samples) { $0.quantity.doubleValue(for: HKUnit(from: "count/min") ?? HKUnit.count().unitDivided(by: .minute())) }
            }
            if let samples = try? await healthKit.fetchHRVSamples(from: start, to: end) {
                hrvSamples = dailyAggregate(samples) { $0.quantity.doubleValue(for: HKUnit.secondUnit(with: .milli)) }
            }
            if let sleepSamples = try? await healthKit.fetchSleepSamples(from: start, to: end) {
                sleepHours = dailySleepAggregate(sleepSamples)
            }
            if let tempSamples = try? await healthKit.fetchWristTemperatures(from: start, to: end) {
                let converted = tempSamples.map {
                    WristTemperatureSample(date: $0.startDate, value: $0.quantity.doubleValue(for: .degreeCelsius()))
                }
                wristTemperatures = converted
                temperatureAnalysis = WristTemperatureCalibrator.analyze(converted)
            } else {
                temperatureAnalysis = .notEnoughData
            }
        } else {
            temperatureAnalysis = .notEnoughData
        }

        lastRefreshed = .now
        loading = false
    }

    private func dailyAggregate(_ samples: [HKQuantitySample], value: (HKQuantitySample) -> Double) -> [(date: Date, value: Double)] {
        var grouped: [Date: [Double]] = [:]
        for sample in samples {
            let day = Calendar.current.startOfDay(for: sample.startDate)
            grouped[day, default: []].append(value(sample))
        }
        return grouped.keys.sorted().map { day in
            let values = grouped[day]!
            return (day, values.reduce(0, +) / Double(values.count))
        }
    }

    private func dailySleepAggregate(_ samples: [HKCategorySample]) -> [(date: Date, value: Double)] {
        let asleep: Set<HKCategoryValueSleepAnalysis> = [.asleepUnspecified, .asleepCore, .asleepDeep, .asleepREM]
        var grouped: [Date: Double] = [:]
        for sample in samples {
            guard let value = HKCategoryValueSleepAnalysis(rawValue: sample.value), asleep.contains(value) else { continue }
            let day = Calendar.current.startOfDay(for: sample.startDate)
            grouped[day, default: 0] += sample.endDate.timeIntervalSince(sample.startDate) / 3600.0
        }
        return grouped.keys.sorted().map { ($0, grouped[$0]!) }
    }
}
