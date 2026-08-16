import Foundation

/// App Group 共享容器（iPhone ↔ Watch App ↔ Watch Widget）
public enum WatchSharedStorage {
    public static let appGroupID = "group.com.ylovel.app"
    private static let summaryKey = "watchPredictionSummary"

    public static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroupID) ?? .standard
    }

    public static func saveSummary(_ summary: WatchMessage.PredictionSummary) {
        if let data = WatchMessage.encode(summary) {
            defaults.set(data, forKey: summaryKey)
        }
    }

    public static func loadSummary() -> WatchMessage.PredictionSummary? {
        guard let data = defaults.data(forKey: summaryKey) else { return nil }
        return WatchMessage.decodePredictionSummary(data)
    }
}
