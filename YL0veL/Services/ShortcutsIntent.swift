import Foundation
import AppIntents
import HealthKit

/// Siri / 快捷指令：「记录我今天的经量」（写入 HealthKit；本地库在下次打开 App 时镜像同步）
struct LogPeriodIntent: AppIntent {

    static var title: LocalizedStringResource = "记录经期"
    static var description = IntentDescription("记录今天的经期状况到 YL0veL 与 Apple 健康")

    @Parameter(title: "经血量", default: FlowAmount.medium)
    var flow: FlowAmount

    enum FlowAmount: String, AppEnum {
        case light = "少量"
        case medium = "中等"
        case heavy = "大量"

        static var typeDisplayRepresentation: TypeDisplayRepresentation = "经血量"
        static var caseDisplayRepresentations: [FlowAmount: DisplayRepresentation] = [
            .light: "少量",
            .medium: "中等",
            .heavy: "大量",
        ]
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw IntentError.message("当前设备不支持健康数据")
        }
        let store = HKHealthStore()
        let type = HKObjectType.categoryType(forIdentifier: .menstrualFlow)!
        try await store.requestAuthorization(toShare: [type], read: [])

        let value: HKCategoryValueMenstrualFlow = switch flow {
        case .light: .light
        case .medium: .medium
        case .heavy: .heavy
        }
        let day = Calendar.current.startOfDay(for: .now)
        let sample = HKCategorySample(type: type, value: value.rawValue, start: day, end: day.addingTimeInterval(3600))
        try await store.save(sample)

        // 同步 App Group 摘要（周期信息不依赖 App 打开）
        return .result()
    }

    enum IntentError: Error, CustomLocalizedStringResourceConvertible {
        case message(String)

        var localizedStringResource: LocalizedStringResource {
            switch self {
            case .message(let text): return LocalizedStringResource(stringLiteral: text)
            }
        }
    }
}
