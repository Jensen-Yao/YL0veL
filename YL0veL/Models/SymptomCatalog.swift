import Foundation
import SwiftData

/// 排卵期关注模式（影响排卵窗口的展示与提醒语气）
enum CycleMode: String, CaseIterable, Codable {
    case dailyCare
    case tryingToConceive
    case avoidingPregnancy

    var displayName: String {
        switch self {
        case .dailyCare: return "日常守护"
        case .tryingToConceive: return "备孕"
        case .avoidingPregnancy: return "避孕"
        }
    }
}

/// 症状词表（编码借鉴 drip 的 pain 体系，中文展示本地化）
enum SymptomCatalog {
    /// 疼痛/不适类症状（可多选）
    static let painSymptoms: [(code: String, name: String, emoji: String)] = [
        ("cramps", "痛经", "🩹"),
        ("ovulationPain", "排卵痛", "💫"),
        ("headache", "头痛", "🤕"),
        ("backache", "腰酸背痛", "🧘‍♀️"),
        ("nausea", "恶心", "🤢"),
        ("tenderBreasts", "乳房胀痛", "🌷"),
        ("migraine", "偏头痛", "💥"),
        ("fatigue", "疲劳", "🥱"),
        ("bloating", "腹胀", "🎈"),
        ("dizziness", "头晕", "💫"),
        ("acne", "长痘", "🫧"),
        ("diarrhea", "腹泻", "💨"),
        ("insomnia", "失眠", "🌙"),
        ("appetiteChange", "食欲变化", "🍽"),
    ]

    /// 情绪（单选）
    static let moods: [(code: String, name: String, emoji: String)] = [
        ("happy", "开心", "😊"),
        ("calm", "平静", "😌"),
        ("irritated", "烦躁", "😤"),
        ("sad", "难过", "😢"),
        ("anxious", "焦虑", "😰"),
        ("tired", "疲惫", "😪"),
        ("energetic", "活力", "⚡"),
    ]

    /// 宫颈黏液（单选，感觉维度）
    static let mucusTypes: [(code: String, name: String)] = [
        ("dry", "干燥"),
        ("sticky", "黏稠"),
        ("creamy", "乳状"),
        ("eggWhite", "蛋清状"),
        ("watery", "水样"),
    ]

    /// 黏液质地（参考 drip 的 texture 维度）
    static let mucusTextures: [(code: String, name: String)] = [
        ("smooth", "光滑"),
        ("lumpy", "块状"),
        ("stretchy", "可拉丝"),
        ("clear", "清亮"),
        ("cloudy", "浑浊"),
    ]

    /// 宫颈状态（参考 drip 的 cervix 三维度）
    static let cervixOpenings: [(code: String, name: String)] = [
        ("closed", "闭合"),
        ("partiallyOpen", "微开"),
        ("open", "张开"),
    ]

    static let cervixFirmnesses: [(code: String, name: String)] = [
        ("firm", "偏硬"),
        ("medium", "中等"),
        ("soft", "偏软"),
    ]

    static let cervixPositions: [(code: String, name: String)] = [
        ("low", "低"),
        ("medium", "中"),
        ("high", "高"),
    ]

    /// 欲望（参考 drip 的 desire）
    static let desires: [(code: String, name: String, emoji: String)] = [
        ("low", "低", "🌑"),
        ("medium", "中", "🌗"),
        ("high", "高", "🌕"),
    ]

    /// 睡眠自评
    static let sleepQualities: [(code: String, name: String, emoji: String)] = [
        ("good", "睡得很好", "😴"),
        ("ok", "一般般", "😪"),
        ("bad", "没睡好", "🥱"),
    ]

    /// 避孕方式（参考 drip 的 sex 记录）
    static let contraceptionMethods: [(code: String, name: String)] = [
        ("none", "未避孕"),
        ("condom", "避孕套"),
        ("pill", "短效避孕药"),
        ("iud", "宫内节育器"),
        ("patch", "避孕贴"),
        ("ring", "避孕环"),
        ("implant", "皮下埋植"),
        ("other", "其他"),
    ]

    static func name(forCode code: String, in list: [(code: String, name: String, emoji: String)]) -> String {
        list.first(where: { $0.code == code })?.name ?? code
    }

    static func painName(forCode code: String) -> String {
        painSymptoms.first(where: { $0.code == code })?.name ?? code
    }

    static func moodName(forCode code: String) -> String {
        moods.first(where: { $0.code == code })?.name ?? code
    }
}
