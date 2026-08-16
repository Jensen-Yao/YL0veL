import Foundation
import UserNotifications
import YL0veLPredictionKit

/// 本地提醒服务（参考 drip `lib/notifications.js` 交互：预测窗首日 −N 天早 6 点，文案带区间；数据变化自动重排）
final class NotificationService {

    static let shared = NotificationService()

    static let periodReminderID = "com.ylovel.reminder.period"
    static let temperatureReminderID = "com.ylovel.reminder.temperature"
    static let reportReadyID = "com.ylovel.reminder.report"

    private let center = UNUserNotificationCenter.current()

    private init() {}

    func requestAuthorization() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    /// 经期提醒：预测窗口首日 −N 天，在设定时刻推送；文案带预测区间
    func schedulePeriodReminder(prediction: CyclePrediction, advanceNoticeDays: Int, hour: Int, minute: Int = 0) async {
        center.removePendingNotificationRequests(withIdentifiers: [Self.periodReminderID])

        let window = prediction.nextMensesWindow
        guard let windowFirst = window.first, let windowLast = window.last else { return }

        var components = Calendar.current.dateComponents([.year, .month, .day], from: windowFirst)
        components.day! -= advanceNoticeDays
        components.hour = hour
        components.minute = minute

        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日"
        let rangeText = "\(formatter.string(from: windowFirst)) ~ \(formatter.string(from: windowLast))"

        let content = UNMutableNotificationContent()
        content.title = "YL0veL · 经期将至 🌸"
        content.body = "经期预计在 \(advanceNoticeDays) 天后开始（预测窗口 \(rangeText)）。提前备好暖宝宝和红糖水哦 💗"
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: Self.periodReminderID, content: content, trigger: trigger)
        try? await center.add(request)
    }

    /// 每日体温/晨起记录提醒（可选）
    func scheduleDailyReminder(enabled: Bool, hour: Int, title: String, body: String, identifier: String) async {
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        guard enabled else { return }
        var components = DateComponents()
        components.hour = hour
        components.minute = 0
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        try? await center.add(request)
    }

    /// 周期报告生成完成提醒
    func scheduleReportReadyNotification(title: String) async {
        let content = UNMutableNotificationContent()
        content.title = "YL0veL · 周期报告已生成 📋"
        content.body = title + "，点开看看这个周期的身体变化吧"
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: Self.reportReadyID, content: content, trigger: trigger)
        try? await center.add(request)
    }

    func cancelPeriodReminder() {
        center.removePendingNotificationRequests(withIdentifiers: [Self.periodReminderID])
    }

    /// 记录变化后自动重排经期提醒（drip 交互：数据变化 → 重算预测 → 重排）
    @MainActor
    func refreshPeriodReminderIfNeeded(cycleStore: CycleStore, settings: AppSettings? = nil) async {
        guard let prediction = PredictionEngine().predict(cycleStarts: cycleStore.cycleStarts()) else {
            cancelPeriodReminder()
            return
        }
        await schedulePeriodReminder(
            prediction: prediction,
            advanceNoticeDays: settings?.advanceNoticeDays ?? 2,
            hour: settings?.reminderHour ?? 6
        )
    }
}
