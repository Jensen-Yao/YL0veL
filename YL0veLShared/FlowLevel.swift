import Foundation

/// 经期流量分级（映射 HealthKit HKCategoryValueMenstrualFlow）
public enum FlowLevel: Int, CaseIterable, Codable, Sendable {
    case none = 0
    case light = 1
    case medium = 2
    case heavy = 3

    public var displayName: String {
        switch self {
        case .none: return "无"
        case .light: return "少量"
        case .medium: return "中等"
        case .heavy: return "大量"
        }
    }

    public var emoji: String {
        switch self {
        case .none: return "⚪"
        case .light: return "🩷"
        case .medium: return "❤️"
        case .heavy: return "💗"
        }
    }
}
