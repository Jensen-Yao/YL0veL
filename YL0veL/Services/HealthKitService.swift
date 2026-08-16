import Foundation
import HealthKit

/// HealthKit 服务：授权 + 经期双向读写 + 健康量（心率/HRV/睡眠/手腕温度）只读聚合
/// 自适应：手腕温度在无传感器设备上读不到样本，调用方据此降级（见 WristTemperatureCalibrator）
final class HealthKitService: ObservableObject {

    static let shared = HealthKitService()

    let store = HKHealthStore()
    @Published private(set) var isAuthorized = false

    private init() {}

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    /// 可写类型（经期相关）
    var typesToWrite: Set<HKSampleType> {
        var types: Set<HKSampleType> = [
            HKObjectType.categoryType(forIdentifier: .menstrualFlow)!,
            HKObjectType.categoryType(forIdentifier: .cervicalMucusQuality)!,
            HKObjectType.categoryType(forIdentifier: .ovulationTestResult)!,
            HKObjectType.categoryType(forIdentifier: .sexualActivity)!,
            HKObjectType.quantityType(forIdentifier: .basalBodyTemperature)!,
        ]
        if #available(iOS 16.0, *) {
            types.insert(HKObjectType.categoryType(forIdentifier: .intermenstrualBleeding)!)
        }
        return types
    }

    /// 可读类型（经期 + 健康量 + 手腕温度）
    var typesToRead: Set<HKObjectType> {
        var types: Set<HKObjectType> = [
            HKObjectType.categoryType(forIdentifier: .menstrualFlow)!,
            HKObjectType.categoryType(forIdentifier: .cervicalMucusQuality)!,
            HKObjectType.categoryType(forIdentifier: .ovulationTestResult)!,
            HKObjectType.categoryType(forIdentifier: .sexualActivity)!,
            HKObjectType.quantityType(forIdentifier: .basalBodyTemperature)!,
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!,
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!,
        ]
        if #available(iOS 16.0, *) {
            types.insert(HKObjectType.categoryType(forIdentifier: .intermenstrualBleeding)!)
            types.insert(HKObjectType.quantityType(forIdentifier: .appleSleepingWristTemperature)!)
        }
        return types
    }

    // MARK: - 授权

    @MainActor
    func requestAuthorization() async throws {
        guard isAvailable else { throw HealthKitError.unavailable }
        try await store.requestAuthorization(toShare: typesToWrite, read: typesToRead)
        isAuthorized = true
    }

    // MARK: - 写入

    func saveMenstrualFlow(on day: Date, value: HKCategoryValueMenstrualFlow) async throws {
        let type = HKObjectType.categoryType(forIdentifier: .menstrualFlow)!
        let start = Calendar.current.startOfDay(for: day)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start)!
        let sample = HKCategorySample(type: type, value: value.rawValue, start: start, end: end)
        try await store.save(sample)
    }

    func deleteMenstrualFlow(on day: Date) async throws {
        let type = HKObjectType.categoryType(forIdentifier: .menstrualFlow)!
        let start = Calendar.current.startOfDay(for: day)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start)!
        let samples = try await fetchCategorySamples(type: type, from: start, to: end)
        for sample in samples {
            try await store.delete(sample)
        }
    }

    func saveBasalBodyTemperature(on day: Date, value: Double) async throws {
        let type = HKObjectType.quantityType(forIdentifier: .basalBodyTemperature)!
        let start = Calendar.current.startOfDay(for: day)
        let quantity = HKQuantity(unit: .degreeCelsius(), doubleValue: value)
        let sample = HKQuantitySample(type: type, quantity: quantity, start: start, end: start.addingTimeInterval(60))
        try await store.save(sample)
    }

    // MARK: - 读取

    func fetchMenstrualFlow(from start: Date, to end: Date) async throws -> [HKCategorySample] {
        let type = HKObjectType.categoryType(forIdentifier: .menstrualFlow)!
        return try await fetchCategorySamples(type: type, from: start, to: end)
    }

    /// 手腕温度（每晚一个样本）；无传感器设备返回空数组 → 调用方自适应降级
    func fetchWristTemperatures(from start: Date, to end: Date) async throws -> [HKQuantitySample] {
        guard #available(iOS 16.0, *) else { return [] }
        let type = HKObjectType.quantityType(forIdentifier: .appleSleepingWristTemperature)!
        let samples = try await fetchQuantitySamples(type: type, from: start, to: end)
        // 按天聚合（同一天多个样本取均值）
        return aggregateDaily(samples)
    }

    func fetchHeartRateSamples(from start: Date, to end: Date) async throws -> [HKQuantitySample] {
        let type = HKObjectType.quantityType(forIdentifier: .heartRate)!
        return try await fetchQuantitySamples(type: type, from: start, to: end)
    }

    func fetchHRVSamples(from start: Date, to end: Date) async throws -> [HKQuantitySample] {
        let type = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!
        return try await fetchQuantitySamples(type: type, from: start, to: end)
    }

    func fetchSleepSamples(from start: Date, to end: Date) async throws -> [HKCategorySample] {
        let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        return try await fetchCategorySamples(type: type, from: start, to: end)
    }

    // MARK: - 统计便捷方法

    func averageHeartRate(from start: Date, to end: Date) async throws -> Double? {
        let samples = try await fetchHeartRateSamples(from: start, to: end)
        let values = samples.map { $0.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute())) }
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    func averageHRV(from start: Date, to end: Date) async throws -> Double? {
        let samples = try await fetchHRVSamples(from: start, to: end)
        let values = samples.map { $0.quantity.doubleValue(for: HKUnit.secondUnit(with: .milli)) }
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    func averageSleepHours(from start: Date, to end: Date) async throws -> Double? {
        let samples = try await fetchSleepSamples(from: start, to: end)
        let asleepValues: Set<HKCategoryValueSleepAnalysis> = [.asleepUnspecified, .asleepCore, .asleepDeep, .asleepREM]
        let totalSeconds = samples
            .filter { sample in
                guard let value = HKCategoryValueSleepAnalysis(rawValue: sample.value) else { return false }
                return asleepValues.contains(value)
            }
            .reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }
        let days = max(1.0, end.timeIntervalSince(start) / 86400.0)
        return totalSeconds / 3600.0 / days
    }

    // MARK: - Private helpers

    private func fetchCategorySamples(type: HKCategoryType, from start: Date, to end: Date) async throws -> [HKCategorySample] {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: (samples as? [HKCategorySample]) ?? [])
                }
            }
            store.execute(query)
        }
    }

    private func fetchQuantitySamples(type: HKQuantityType, from start: Date, to end: Date) async throws -> [HKQuantitySample] {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: (samples as? [HKQuantitySample]) ?? [])
                }
            }
            store.execute(query)
        }
    }

    /// 同一天多个样本按天取均值（手腕温度每晚一个，个别情况多样本）
    private func aggregateDaily(_ samples: [HKQuantitySample]) -> [HKQuantitySample] {
        var grouped: [Date: [Double]] = [:]
        for sample in samples {
            let day = Calendar.current.startOfDay(for: sample.startDate)
            grouped[day, default: []].append(sample.quantity.doubleValue(for: .degreeCelsius()))
        }
        return grouped.keys.sorted().map { day in
            let values = grouped[day]!
            let mean = values.reduce(0, +) / Double(values.count)
            return HKQuantitySample(
                type: HKObjectType.quantityType(forIdentifier: .appleSleepingWristTemperature)!,
                quantity: HKQuantity(unit: .degreeCelsius(), doubleValue: mean),
                start: day,
                end: day.addingTimeInterval(3600)
            )
        }
    }
}

enum HealthKitError: Error, LocalizedError {
    case unavailable

    var errorDescription: String? {
        switch self {
        case .unavailable: return "当前设备不支持健康数据"
        }
    }
}
