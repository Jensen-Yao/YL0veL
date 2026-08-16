import Foundation
import SwiftData
import YL0veLPredictionKit

/// 报告服务：检测经期结束（自动判定 + 手动确认）→ 聚合健康数据 → 生成周期报告
@MainActor
final class ReportService: ObservableObject {

    private let modelContext: ModelContext
    private let cycleStore: CycleStore
    private let healthKit: HealthKitService
    private let generator = CycleReportGenerator()

    /// 经期结束后连续无流量天数阈值，触发自动结束判定（与计划一致：5 天）
    static let autoEndAfterDaysWithoutFlow = 5

    @Published private(set) var reports: [CycleReport] = []

    init(modelContext: ModelContext, cycleStore: CycleStore, healthKit: HealthKitService = .shared) {
        self.modelContext = modelContext
        self.cycleStore = cycleStore
        self.healthKit = healthKit
        reload()
    }

    // MARK: - 查询

    func report(forCycleStartingAt date: Date) -> CycleReport? {
        reports.first { $0.cycleStartDate == date }
    }

    private func reload() {
        let descriptor = FetchDescriptor<CycleReport>(sortBy: [SortDescriptor(\.cycleStartDate, order: .reverse)])
        reports = (try? modelContext.fetch(descriptor)) ?? []
    }

    // MARK: - 结束检测与报告生成

    /// 检查是否有「已结束但未生成报告」的周期；返回新生成的报告（供 UI 提示）
    @discardableResult
    func checkAndGenerateReports() async throws -> [CycleReport] {
        let starts = cycleStore.cycleStarts() // 最新在前
        var generated: [CycleReport] = []

        // 进行中的周期（最新）结束后检测自动判定
        for index in 0..<max(0, starts.count - 1) {
            let cycleStart = starts[index]
            let nextStart = starts[index + 1]
            let cycleEnd = Calendar.current.date(byAdding: .day, value: -1, to: nextStart)!

            if report(forCycleStartingAt: cycleStart) == nil {
                let report = try await generateReport(cycleStart: cycleStart, cycleEnd: cycleEnd)
                modelContext.insert(report)
                generated.append(report)
            }
        }

        // 当前进行中的周期：若最后出血日距今 ≥5 天，自动判定结束（生成预览由 UI 确认后落库）
        if let currentStart = starts.first, report(forCycleStartingAt: currentStart) == nil {
            if let lastFlowDay = lastFlowDay(after: currentStart) {
                let daysSince = Calendar.current.dateComponents([.day], from: lastFlowDay, to: .now).day ?? 0
                if daysSince >= Self.autoEndAfterDaysWithoutFlow {
                    let cycleEnd = Calendar.current.date(byAdding: .day, value: -1, to: .now)!
                    let report = try await generateReport(cycleStart: currentStart, cycleEnd: cycleEnd)
                    modelContext.insert(report)
                    generated.append(report)
                }
            }
        }

        try modelContext.save()
        reload()
        return generated
    }

    /// 手动结束当前周期并生成报告
    func manuallyEndCurrentCycle() async throws -> CycleReport? {
        guard let currentStart = cycleStore.currentCycleStart else { return nil }
        if let existing = report(forCycleStartingAt: currentStart) { return existing }
        let cycleEnd = Calendar.current.date(byAdding: .day, value: -1, to: .now)!
        let report = try await generateReport(cycleStart: currentStart, cycleEnd: cycleEnd)
        modelContext.insert(report)
        try modelContext.save()
        reload()
        return report
    }

    // MARK: - Private

    private func lastFlowDay(after start: Date) -> Date? {
        cycleStore.cycleDays
            .filter { $0.date >= start && $0.flow > 0 }
            .map(\.date)
            .max()
    }

    private func generateReport(cycleStart: Date, cycleEnd: Date) async throws -> CycleReport {
        let allStarts = cycleStore.cycleStarts()
        let days = cycleStore.days(in: cycleStart...cycleEnd)
        let cycleLength = Calendar.current.dateComponents([.day], from: cycleStart, to: cycleEnd).day ?? 0

        // 健康数据聚合（HealthKit 未授权时降级为 nil）
        var metrics = CycleReportGenerator.HealthMetrics()
        if healthKit.isAvailable && healthKit.isAuthorized {
            metrics.averageHeartRate = try? await healthKit.averageHeartRate(from: cycleStart, to: cycleEnd)
            metrics.averageHRV = try? await healthKit.averageHRV(from: cycleStart, to: cycleEnd)
            metrics.averageSleepHours = try? await healthKit.averageSleepHours(from: cycleStart, to: cycleEnd)
            if let samples = try? await healthKit.fetchWristTemperatures(from: cycleStart, to: cycleEnd), !samples.isEmpty {
                let converted = samples.map { WristTemperatureSample(date: $0.startDate, value: $0.quantity.doubleValue(for: .degreeCelsius())) }
                let analysis = WristTemperatureCalibrator.analyze(converted)
                metrics.averageWristTemperatureDeviation = analysis.latestDeviation
            }
        }

        // 上一个周期的报告（对比）
        let previousCycleStart = allStarts.dropFirst().first

        let input = CycleReportGenerator.Input(
            cycleStart: cycleStart,
            cycleEnd: cycleEnd,
            cycleLength: cycleLength,
            days: days,
            cycleStarts: allStarts,
            health: metrics,
            previousReport: previousCycleStart.flatMap { report(forCycleStartingAt: $0) }
        )
        return generator.generate(from: input)
    }
}
