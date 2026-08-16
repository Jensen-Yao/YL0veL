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
        if wristTemperatures.isEmpty {
            return "未读取到手腕温度。Apple Watch SE 3 / Series 8 及更新机型在佩戴入睡时会自动记录；你的手表若为更早型号则无此功能（已自动跳过，不影响其他预测）。"
        }
        return "温度基线建立中：需要连续佩戴睡眠约 5 晚。"
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
                    Text("暂无数据（授权后自动读取）")
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
        for sample in samples where asleep.contains(HKCategoryValueSleepAnalysis(rawValue: sample.value)) {
            let day = Calendar.current.startOfDay(for: sample.startDate)
            grouped[day, default: 0] += sample.endDate.timeIntervalSince(sample.startDate) / 3600.0
        }
        return grouped.keys.sorted().map { ($0, grouped[$0]!) }
    }
}
