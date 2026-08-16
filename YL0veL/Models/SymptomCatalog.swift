import Foundation
import SwiftData

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

    /// 宫颈黏液（单选）
    static let mucusTypes: [(code: String, name: String)] = [
        ("dry", "干燥"),
        ("sticky", "黏稠"),
        ("creamy", "乳状"),
        ("eggWhite", "蛋清状"),
        ("watery", "水样"),
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
