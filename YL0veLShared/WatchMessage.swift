import Foundation

/// iPhone ↔ Watch 共享消息（WCSession 传输，JSON 编码）
public enum WatchMessage {

    /// Watch → iPhone：快捷记录草稿
    public struct QuickLog: Codable, Equatable {
        public var date: Date
        public var flow: Int
        public var symptoms: [String]

        public init(date: Date, flow: Int, symptoms: [String]) {
            self.date = date
            self.flow = flow
            self.symptoms = symptoms
        }
    }

    /// iPhone → Watch：预测摘要（表盘/complication 展示）
    public struct PredictionSummary: Codable, Equatable {
        public var cycleDayNumber: Int
        public var daysUntilNextMenses: Int?
        public var nextWindowStart: Date?
        public var nextWindowEnd: Date?

        public init(cycleDayNumber: Int, daysUntilNextMenses: Int?, nextWindowStart: Date?, nextWindowEnd: Date?) {
            self.cycleDayNumber = cycleDayNumber
            self.daysUntilNextMenses = daysUntilNextMenses
            self.nextWindowStart = nextWindowStart
            self.nextWindowEnd = nextWindowEnd
        }
    }

    /// 消息类型键
    public enum Kind: String {
        case quickLog = "quickLog"
        case predictionSummary = "predictionSummary"
    }

    // MARK: - 编解码

    static func encode<T: Encodable>(_ value: T) -> Data? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try? encoder.encode(value)
    }

    static func decodeQuickLog(_ data: Data) -> QuickLog? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(QuickLog.self, from: data)
    }

    static func decodePredictionSummary(_ data: Data) -> PredictionSummary? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(PredictionSummary.self, from: data)
    }
}
