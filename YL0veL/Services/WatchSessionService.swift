import Foundation
import WatchConnectivity
import YL0veLPredictionKit

/// iPhone 端手表通信（系统 WCSession，等价 uni-app 生态 hy-WatchConnectivity 的能力）
/// 双通道互备：WCSession 不可达时，Watch 端直写 HealthKit 经 iCloud 健康同步回 iPhone
final class WatchSessionService: NSObject, ObservableObject {

    static let shared = WatchSessionService()

    /// Watch 快捷记录回调（由上层注入写入 CycleStore）
    @MainActor var onQuickLogReceived: ((WatchMessage.QuickLog) -> Void)?

    private override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    var isPaired: Bool {
        WCSession.isSupported() && WCSession.default.isPaired
    }

    /// 推送预测摘要到手表（表盘/complication 展示）
    func sendPredictionSummary(_ summary: WatchMessage.PredictionSummary) {
        guard WCSession.isSupported(), WCSession.default.activationState == .activated else { return }
        guard let data = WatchMessage.encode(summary) else { return }
        let payload: [String: Any] = [WatchMessage.Kind.predictionSummary.rawValue: data]
        do {
            try WCSession.default.updateApplicationContext(payload)
        } catch {
            // 表盘数据非关键路径，静默失败（HealthKit 兜底通道仍可用）
        }
    }

    /// 由预测引擎结果构建摘要
    func summary(from prediction: CyclePrediction?, cycleStarts: [Date], calendar: Calendar = .current) -> WatchMessage.PredictionSummary {
        var cycleDayNumber = 1
        if let currentStart = cycleStarts.first {
            cycleDayNumber = (calendar.dateComponents([.day], from: currentStart, to: calendar.startOfDay(for: .now)).day ?? 0) + 1
        }
        var daysUntil: Int?
        if let window = prediction?.nextMensesWindow.first {
            daysUntil = calendar.dateComponents([.day], from: calendar.startOfDay(for: .now), to: window).day
        }
        return WatchMessage.PredictionSummary(
            cycleDayNumber: cycleDayNumber,
            daysUntilNextMenses: daysUntil,
            nextWindowStart: prediction?.nextMensesWindow.first,
            nextWindowEnd: prediction?.nextMensesWindow.last
        )
    }
}

// MARK: - WCSessionDelegate

extension WatchSessionService: WCSessionDelegate {

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}

    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        guard let data = message[WatchMessage.Kind.quickLog.rawValue] as? Data,
              let quickLog = WatchMessage.decodeQuickLog(data) else { return }
        Task { @MainActor in
            onQuickLogReceived?(quickLog)
        }
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        // iPhone 端一般不接收（Watch → iPhone 走 didReceiveMessage）
    }
}
