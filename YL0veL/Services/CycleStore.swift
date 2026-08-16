import Foundation
import SwiftData
import HealthKit

/// 周期数据仓库：SwiftData 本地镜像 + HealthKit 双向同步 + 周期推导
@MainActor
final class CycleStore: ObservableObject {

    private let modelContext: ModelContext
    private let healthKit: HealthKitService

    @Published private(set) var cycleDays: [CycleDay] = []
    @Published private(set) var cycles: [Cycle] = []

    init(modelContext: ModelContext, healthKit: HealthKitService = .shared) {
        self.modelContext = modelContext
        self.healthKit = healthKit
        reload()
    }

    // MARK: - 查询

    func day(for date: Date) -> CycleDay? {
        let day = Calendar.current.startOfDay(for: date)
        return cycleDays.first { $0.date == day }
    }

    func days(in range: ClosedRange<Date>) -> [CycleDay] {
        let start = Calendar.current.startOfDay(for: range.lowerBound)
        let end = Calendar.current.startOfDay(for: range.upperBound)
        // 防御：区间倒置时返回空（避免 ClosedRange 构造崩溃）
        guard start <= end else { return [] }
        return cycleDays.filter { $0.date >= start && $0.date <= end }
    }

    /// 推导周期开始日（最新在前）：当天有流量且前一天无流量
    func cycleStarts() -> [Date] {
        let sorted = cycleDays.sorted { $0.date < $1.date }
        var starts: [Date] = []
        for (index, day) in sorted.enumerated() where day.flow > 0 {
            let previous = index > 0 ? sorted[index - 1] : nil
            let previousHadFlow = previous != nil && previous!.flow > 0
                && Calendar.current.dateComponents([.day], from: previous!.date, to: day.date).day == 1
            if !previousHadFlow {
                starts.append(day.date)
            }
        }
        return starts.sorted(by: >)
    }

    /// 当前周期（最近一次经期开始日至今）
    var currentCycleStart: Date? {
        cycleStarts().first
    }

    /// 上次完整周期的天数（含出血段），无则 nil
    func completedCycleDayCount() -> Int? {
        let starts = cycleStarts()
        guard starts.count >= 2 else { return nil }
        return Calendar.current.dateComponents([.day], from: starts[1], to: starts[0]).day
    }

    // MARK: - 写入

    /// 保存/更新一天的记录：本地 SwiftData + HealthKit 经期双向同步
    func upsert(_ day: CycleDay) async throws {
        day.updatedAt = .now
        modelContext.insert(day)
        try modelContext.save()

        // HealthKit 同步：仅 flow 字段双向
        if healthKit.isAvailable && healthKit.isAuthorized {
            if day.flow > 0, let hkValue = hkMenstrualFlowValue(for: day.flow) {
                try await healthKit.saveMenstrualFlow(on: day.date, value: hkValue)
            } else {
                try await healthKit.deleteMenstrualFlow(on: day.date)
            }
        }

        reload()
        refreshCycles()
    }

    func delete(_ day: CycleDay) async throws {
        if healthKit.isAvailable && healthKit.isAuthorized {
            try await healthKit.deleteMenstrualFlow(on: day.date)
        }
        modelContext.delete(day)
        try modelContext.save()
        reload()
        refreshCycles()
    }

    /// 从 HealthKit 拉取经期数据镜像到本地（首次启动/导入后调用）
    func mirrorFromHealthKit(from start: Date, to end: Date) async throws {
        guard healthKit.isAvailable && healthKit.isAuthorized else { return }
        let samples = try await healthKit.fetchMenstrualFlow(from: start, to: end)
        for sample in samples {
            let day = Calendar.current.startOfDay(for: sample.startDate)
            let flow = flowLevel(forHKValue: sample.value)
            if flow == 0 { continue }
            let existing = self.day(for: day)
            if let existing {
                existing.flow = flow
            } else {
                let newDay = CycleDay(date: day, flow: flow)
                modelContext.insert(newDay)
            }
        }
        try modelContext.save()
        reload()
        refreshCycles()
    }

    // MARK: - 周期维护

    /// 重建 Cycle 缓存：由 cycleStarts 推导；周期结束 = 下一个周期开始前一天
    func refreshCycles() {
        let starts = cycleStarts()
        cycles = starts.enumerated().map { index, start in
            let end: Date?
            if index > 0 {
                end = Calendar.current.date(byAdding: .day, value: -1, to: starts[index - 1])
            } else {
                end = nil // 进行中
            }
            return Cycle(startDate: start, endDate: end)
        }
    }

    /// 已完成周期（endDate 非空）
    var completedCycles: [Cycle] {
        cycles.filter { $0.endDate != nil }
    }

    // MARK: - Helpers

    private func reload() {
        let descriptor = FetchDescriptor<CycleDay>(sortBy: [SortDescriptor(\.date)])
        cycleDays = (try? modelContext.fetch(descriptor)) ?? []
    }

    private func hkMenstrualFlowValue(for flow: Int) -> HKCategoryValueMenstrualFlow? {
        switch FlowLevel(rawValue: flow) {
        case .light: return .light
        case .medium: return .medium
        case .heavy: return .heavy
        default: return nil
        }
    }

    private func flowLevel(forHKValue value: Int) -> Int {
        switch HKCategoryValueMenstrualFlow(rawValue: value) {
        case .light: return FlowLevel.light.rawValue
        case .medium: return FlowLevel.medium.rawValue
        case .heavy: return FlowLevel.heavy.rawValue
        default: return 0
        }
    }
}
