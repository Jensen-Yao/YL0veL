import Foundation
import SwiftData

/// 每日记录（唯一键：日期，当天零点）
/// 数据真源为 HealthKit（经期部分双向同步），本实体为本地镜像 + App 自有数据（情绪/备注等）
@Model
final class CycleDay {
    @Attribute(.unique) var date: Date
    var flow: Int                    // FlowLevel.rawValue；0 = 未记录流量
    var symptoms: [String]           // SymptomCatalog 编码数组
    var mood: String?                // 情绪编码
    var mucus: String?               // 黏液感觉编码
    var mucusTexture: String?        // 黏液质地编码
    var cervixOpening: String?       // 宫颈开口编码
    var cervixFirmness: String?      // 宫颈硬度编码
    var cervixPosition: String?      // 宫颈位置编码
    var desire: String?              // 欲望编码
    var temperature: Double?         // 手录基础体温（℃）
    var note: String?
    var hasIntercourse: Bool
    var contraception: String?       // 避孕方式编码
    var weight: Double?              // 体重（kg，双向同步 HealthKit）
    var exerciseMinutes: Int         // 运动分钟
    var waterCups: Int               // 饮水杯数
    var sleepQuality: String?        // 睡眠自评编码
    var diary: String?               // 心情日记
    var updatedAt: Date

    init(
        date: Date,
        flow: Int = 0,
        symptoms: [String] = [],
        mood: String? = nil,
        mucus: String? = nil,
        mucusTexture: String? = nil,
        cervixOpening: String? = nil,
        cervixFirmness: String? = nil,
        cervixPosition: String? = nil,
        desire: String? = nil,
        temperature: Double? = nil,
        note: String? = nil,
        hasIntercourse: Bool = false,
        contraception: String? = nil,
        weight: Double? = nil,
        exerciseMinutes: Int = 0,
        waterCups: Int = 0,
        sleepQuality: String? = nil,
        diary: String? = nil,
        updatedAt: Date = .now
    ) {
        self.date = date
        self.flow = flow
        self.symptoms = symptoms
        self.mood = mood
        self.mucus = mucus
        self.mucusTexture = mucusTexture
        self.cervixOpening = cervixOpening
        self.cervixFirmness = cervixFirmness
        self.cervixPosition = cervixPosition
        self.desire = desire
        self.temperature = temperature
        self.note = note
        self.hasIntercourse = hasIntercourse
        self.contraception = contraception
        self.weight = weight
        self.exerciseMinutes = exerciseMinutes
        self.waterCups = waterCups
        self.sleepQuality = sleepQuality
        self.diary = diary
        self.updatedAt = updatedAt
    }

    var flowLevel: FlowLevel { FlowLevel(rawValue: flow) ?? .none }
}

/// 月经周期（由 CycleDay 推导并缓存，用于报告关联）
@Model
final class Cycle {
    var startDate: Date
    var endDate: Date?
    var reportGeneratedAt: Date?

    init(startDate: Date, endDate: Date? = nil) {
        self.startDate = startDate
        self.endDate = endDate
    }

    var cycleLength: Int? {
        guard let endDate else { return nil }
        return Calendar.current.dateComponents([.day], from: startDate, to: endDate).day
    }
}

/// 周期报告（经期结束后生成，内容快照）
@Model
final class CycleReport {
    var cycleStartDate: Date
    var cycleEndDate: Date?
    var generatedAt: Date
    var cycleLength: Int
    var periodLength: Int
    var flowDistribution: [String: Int]       // 流量档位名 → 天数
    var symptomCounts: [String: Int]          // 症状编码 → 次数
    var moodCounts: [String: Int]             // 情绪编码 → 次数
    var averageHeartRate: Double?             // 周期内平均静息心率（来自 HealthKit）
    var averageHRV: Double?                   // 平均 HRV（ms）
    var averageSleepHours: Double?            // 平均睡眠时长（小时）
    var averageWristTemperatureDeviation: Double? // 平均温度偏离（℃），无传感器为 nil
    var regularityScore: Double               // 0–100
    var comparisonSummary: String             // 与上个周期对比摘要
    var careMessage: String                   // Y💗L 关怀文案
    var title: String

    init(
        cycleStartDate: Date,
        cycleEndDate: Date?,
        generatedAt: Date = .now,
        cycleLength: Int,
        periodLength: Int,
        flowDistribution: [String: Int],
        symptomCounts: [String: Int],
        moodCounts: [String: Int],
        averageHeartRate: Double?,
        averageHRV: Double?,
        averageSleepHours: Double?,
        averageWristTemperatureDeviation: Double?,
        regularityScore: Double,
        comparisonSummary: String,
        careMessage: String,
        title: String
    ) {
        self.cycleStartDate = cycleStartDate
        self.cycleEndDate = cycleEndDate
        self.generatedAt = generatedAt
        self.cycleLength = cycleLength
        self.periodLength = periodLength
        self.flowDistribution = flowDistribution
        self.symptomCounts = symptomCounts
        self.moodCounts = moodCounts
        self.averageHeartRate = averageHeartRate
        self.averageHRV = averageHRV
        self.averageSleepHours = averageSleepHours
        self.averageWristTemperatureDeviation = averageWristTemperatureDeviation
        self.regularityScore = regularityScore
        self.comparisonSummary = comparisonSummary
        self.careMessage = careMessage
        self.title = title
    }
}

/// 管家对话消息（持久化聊天记录）
@Model
final class ButlerMessage {
    var id: UUID
    var role: String      // "user" / "butler"
    var text: String
    var timestamp: Date

    init(id: UUID = UUID(), role: String, text: String, timestamp: Date = .now) {
        self.id = id
        self.role = role
        self.text = text
        self.timestamp = timestamp
    }
}

/// LLM 配置（apiKey 本体存 Keychain，这里只存引用）
@Model
final class LLMConfig {
    var providerName: String       // "DeepSeek" / "通义千问" / "自定义"
    var baseURL: String
    var model: String
    var apiKeyRef: String         // Keychain 中定位 key 的引用 id
    var enabled: Bool
    var includeCycleContext: Bool // 是否允许 LLM 调用附带周期上下文（默认否，最小化传输）
    var updatedAt: Date

    init(
        providerName: String,
        baseURL: String,
        model: String,
        apiKeyRef: String = "",
        enabled: Bool = false,
        includeCycleContext: Bool = false,
        updatedAt: Date = .now
    ) {
        self.providerName = providerName
        self.baseURL = baseURL
        self.model = model
        self.apiKeyRef = apiKeyRef
        self.enabled = enabled
        self.includeCycleContext = includeCycleContext
        self.updatedAt = updatedAt
    }
}

/// App 设置（单例行）
@Model
final class AppSettings {
    var advanceNoticeDays: Int      // 经期提醒提前天数
    var periodReminderEnabled: Bool
    var temperatureReminderEnabled: Bool
    var reminderHour: Int           // 提醒时刻（小时 0–23）
    var predictionEnabled: Bool
    var temperatureCalibrationEnabled: Bool
    var appLockEnabled: Bool
    var fakePINEnabled: Bool
    var fakePIN: String?
    var hasAcceptedDisclaimer: Bool
    var hasCompletedOnboarding: Bool
    var nickname: String
    var cycleMode: String       // CycleMode.rawValue
    var voiceEnabled: Bool
    var checklist: [String]     // 经期准备清单
    var customSoundEnabled: Bool // 主人语音通知铃声
    var nightCareEnabled: Bool  // 睡前关怀
    var nightCareHour: Int      // 睡前关怀时刻（小时）
    var medicationReminderEnabled: Bool // 用药提醒
    var updatedAt: Date

    init(
        advanceNoticeDays: Int = 2,
        periodReminderEnabled: Bool = true,
        temperatureReminderEnabled: Bool = false,
        reminderHour: Int = 6,
        predictionEnabled: Bool = true,
        temperatureCalibrationEnabled: Bool = true,
        appLockEnabled: Bool = false,
        fakePINEnabled: Bool = false,
        fakePIN: String? = nil,
        hasAcceptedDisclaimer: Bool = false,
        hasCompletedOnboarding: Bool = false,
        nickname: String = "桃桃",
        cycleMode: String = CycleMode.dailyCare.rawValue,
        voiceEnabled: Bool = false,
        checklist: [String] = ["卫生巾", "暖宝宝", "红糖", "止痛药"],
        customSoundEnabled: Bool = true,
        nightCareEnabled: Bool = true,
        nightCareHour: Int = 22,
        medicationReminderEnabled: Bool = false,
        updatedAt: Date = .now
    ) {
        self.advanceNoticeDays = advanceNoticeDays
        self.periodReminderEnabled = periodReminderEnabled
        self.temperatureReminderEnabled = temperatureReminderEnabled
        self.reminderHour = reminderHour
        self.predictionEnabled = predictionEnabled
        self.temperatureCalibrationEnabled = temperatureCalibrationEnabled
        self.appLockEnabled = appLockEnabled
        self.fakePINEnabled = fakePINEnabled
        self.fakePIN = fakePIN
        self.hasAcceptedDisclaimer = hasAcceptedDisclaimer
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.nickname = nickname
        self.cycleMode = cycleMode
        self.voiceEnabled = voiceEnabled
        self.checklist = checklist
        self.customSoundEnabled = customSoundEnabled
        self.nightCareEnabled = nightCareEnabled
        self.nightCareHour = nightCareHour
        self.medicationReminderEnabled = medicationReminderEnabled
        self.updatedAt = updatedAt
    }
}
