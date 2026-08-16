import SwiftUI
import WatchConnectivity
import HealthKit

@main
struct YL0veLWatchApp: App {
    @StateObject private var watchSession = WatchSessionService.shared
    @StateObject private var watchHealth = WatchHealthService.shared

    var body: some Scene {
        WindowGroup {
            WatchHomeView()
                .environmentObject(watchSession)
                .environmentObject(watchHealth)
                .task {
                    watchSession.activate()
                    await watchHealth.requestAuthorization()
                }
        }
    }
}

/// Watch 端会话与健康服务
final class WatchSessionService: NSObject, ObservableObject {

    static let shared = WatchSessionService()

    @Published private(set) var summary: WatchMessage.PredictionSummary?

    private override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func activate() {
        if WCSession.default.activationState != .activated {
            WCSession.default.activate()
        }
    }

    /// 手表快捷记录 → iPhone（实时；iPhone 不可达时落 HealthKit 兜底）
    func sendQuickLog(date: Date, flow: Int, symptoms: [String]) {
        let quickLog = WatchMessage.QuickLog(date: date, flow: flow, symptoms: symptoms)
        guard let data = WatchMessage.encode(quickLog) else { return }
        if WCSession.default.isReachable {
            WCSession.default.sendMessage([WatchMessage.Kind.quickLog.rawValue: data], replyHandler: nil) { [weak self] _ in
                self?.fallbackToHealthKit(quickLog: quickLog)
            }
        } else {
            fallbackToHealthKit(quickLog: quickLog)
        }
    }

    /// 兜底：直写 HealthKit（经 iCloud 健康同步回 iPhone）
    private func fallbackToHealthKit(quickLog: WatchMessage.QuickLog) {
        Task {
            await WatchHealthService.shared.saveMenstrualFlowIfPossible(date: quickLog.date, flow: quickLog.flow)
        }
    }
}

extension WatchSessionService: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        if let data = applicationContext[WatchMessage.Kind.predictionSummary.rawValue] as? Data,
           let decoded = WatchMessage.decodePredictionSummary(data) {
            DispatchQueue.main.async {
                self.summary = decoded
            }
            // 写入 App Group 供表盘复杂功能读取
            WatchSharedStorage.saveSummary(decoded)
        }
    }
}

/// Watch 端轻量 HealthKit（保存经期 + 读健康摘要）
final class WatchHealthService: ObservableObject {

    static let shared = WatchHealthService()

    private let store = HKHealthStore()
    @Published private(set) var isAuthorized = false
    @Published var latestHeartRate: Double?
    @Published var latestHRV: Double?
    @Published var lastNightSleepHours: Double?

    private init() {}

    func requestAuthorization() async {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        var write: Set<HKSampleType> = [HKObjectType.categoryType(forIdentifier: .menstrualFlow)!]
        var read: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!,
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!,
        ]
        if #available(watchOS 9.0, *) {
            read.insert(HKObjectType.quantityType(forIdentifier: .appleSleepingWristTemperature)!)
            write.insert(HKObjectType.categoryType(forIdentifier: .cervicalMucusQuality)!)
        }
        try? await store.requestAuthorization(toShare: write, read: read)
        await MainActor.run { isAuthorized = true }
    }

    func saveMenstrualFlowIfPossible(date: Date, flow: Int) async {
        guard isAuthorized else { return }
        guard let hkValue: HKCategoryValueMenstrualFlow = {
            switch FlowLevel(rawValue: flow) {
            case .light: return .light
            case .medium: return .medium
            case .heavy: return .heavy
            default: return nil
            }
        }() else { return }
        let type = HKObjectType.categoryType(forIdentifier: .menstrualFlow)!
        let start = Calendar.current.startOfDay(for: date)
        let sample = HKCategorySample(type: type, value: hkValue.rawValue, start: start, end: start.addingTimeInterval(3600))
        try? await store.save(sample)
    }

    func refreshLatestMetrics() async {
        guard isAuthorized else { return }
        let end = Date()
        let start = Calendar.current.date(byAdding: .day, value: -1, to: end)!

        if let samples = try? await samples(of: HKObjectType.quantityType(forIdentifier: .heartRate)!, from: start, to: end), let last = samples.last {
            let value = last.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
            await MainActor.run { latestHeartRate = value }
        }
        if let samples = try? await samples(of: HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!, from: start, to: end), let last = samples.last {
            let value = last.quantity.doubleValue(for: HKUnit.secondUnit(with: .milli))
            await MainActor.run { latestHRV = value }
        }
        // 昨晚睡眠
        if let samples = try? await categorySamples(of: HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!, from: start, to: end) {
            let asleep: Set<HKCategoryValueSleepAnalysis> = [.asleepUnspecified, .asleepCore, .asleepDeep, .asleepREM]
            let hours = samples.filter { asleep.contains(HKCategoryValueSleepAnalysis(rawValue: $0.value)) }
                .reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) } / 3600.0
            await MainActor.run { lastNightSleepHours = hours > 0 ? hours : nil }
        }
    }

    private func samples(of type: HKQuantityType, from start: Date, to end: Date) async throws -> [HKQuantitySample] {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: 100, sortDescriptors: [sort]) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: (samples as? [HKQuantitySample]) ?? [])
                }
            }
            store.execute(query)
        }
    }

    private func categorySamples(of type: HKCategoryType, from start: Date, to end: Date) async throws -> [HKCategorySample] {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: 100, sortDescriptors: [sort]) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: (samples as? [HKCategorySample]) ?? [])
                }
            }
            store.execute(query)
        }
    }
}
