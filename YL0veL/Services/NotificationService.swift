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

    /// 经期提醒：预测窗口首日 −N 天，在设定时刻推送；文案带预测区间（管家 Y 语气）
    func schedulePeriodReminder(prediction: CyclePrediction, advanceNoticeDays: Int, hour: Int, minute: Int = 0) async {
        center.removePendingNotificationRequests(withIdentifiers: [Self.periodReminderID])

        let window = prediction.nextMensesWindow
        guard let windowFirst = window.first, let windowLast = window.last else { return }

        var components = Calendar.current.dateComponents([.year, .month, .day], from: windowFirst)
        components.day! -= advanceNoticeDays
        components.hour = hour
        components.minute = minute

        let message = YPersona.Notification.periodComing(advanceDays: advanceNoticeDays, windowStart: windowFirst, windowEnd: windowLast)

        let content = UNMutableNotificationContent()
        content.title = message.title
        content.body = message.body
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
        let message = YPersona.Notification.reportReady(reportTitle: title)
        let content = UNMutableNotificationContent()
        content.title = message.title
        content.body = message.body
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: Self.reportReadyID, content: content, trigger: trigger)
        try? await center.add(request)
    }

    /// 经期准备清单逐项提醒（经期前 N 天）
    func scheduleChecklistReminder(item: String, on date: Date, hour: Int) async {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        components.hour = hour
        let message = YPersona.Notification.prepareChecklist(
            item: item,
            daysLeft: max(1, Calendar.current.dateComponents([.day], from: .now, to: date).day ?? 1)
        )
        let content = UNMutableNotificationContent()
        content.title = message.title
        content.body = message.body
        content.sound = .default
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(
            identifier: "\(Self.checklistReminderPrefix)\(item)",
            content: content,
            trigger: trigger
        )
        try? await center.add(request)
    }

    static let checklistReminderPrefix = "com.ylovel.reminder.checklist."

    func cancelChecklistReminders() {
        center.getPendingNotificationRequests { requests in
            let ids = requests
                .map(\.identifier)
                .filter { $0.hasPrefix(Self.checklistReminderPrefix) }
            self.center.removePendingNotificationRequests(withIdentifiers: ids)
        }
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
