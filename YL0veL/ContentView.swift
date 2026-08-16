import SwiftUI
import SwiftData
import YL0veLPredictionKit

/// 主界面 Tab 枚举
enum AppTab: Hashable {
    case calendar
    case insights
    case report
    case settings
}

/// 主界面：日历 / 洞察 / 报告 / 设置 四个 Tab（HIG：直接、具体的标签名）
@MainActor
struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var healthKit = HealthKitService.shared
    @State private var cycleStore: CycleStore?
    @State private var reportService: ReportService?
    @State private var selectedTab: AppTab = .calendar

    var body: some View {
        Group {
            if let cycleStore, let reportService {
                TabView(selection: $selectedTab) {
                    CalendarView()
                        .tabItem { Label("日历", systemImage: "calendar") }
                        .tag(AppTab.calendar)
                    InsightsView()
                        .tabItem { Label("洞察", systemImage: "waveform.path.ecg") }
                        .tag(AppTab.insights)
                    ReportListView()
                        .tabItem { Label("报告", systemImage: "doc.text") }
                        .tag(AppTab.report)
                    SettingsView()
                        .tabItem { Label("设置", systemImage: "gearshape") }
                        .tag(AppTab.settings)
                }
                .environmentObject(cycleStore)
                .environmentObject(reportService)
                .environmentObject(healthKit)
                .task {
                    // 健康数据授权（iOS 系统弹窗，仅一次；CI 截图可跳过）
                    if !skipHealthAuthForScreenshots {
                        try? await healthKit.requestAuthorization()
                    }
                }
                .task {
                    // 周期报告自动生成检查
                    if let newReports = try? await reportService.checkAndGenerateReports(), !newReports.isEmpty {
                        await NotificationService.shared.scheduleReportReadyNotification(title: newReports.first?.title ?? "")
                    }
                }
                .task {
                    // 预测 → 手表推送 + 小组件存储 + 提醒重排
                    pushPredictionToWatch()
                    await NotificationService.shared.refreshPeriodReminderIfNeeded(cycleStore: cycleStore)
                }
                .onChange(of: cycleStore.cycleDays.count) { _, _ in
                    // 记录变化 → 重推预测（手表表盘/小组件即时刷新）
                    pushPredictionToWatch()
                    Task {
                        await NotificationService.shared.refreshPeriodReminderIfNeeded(cycleStore: cycleStore)
                    }
                }
                .onAppear {
                    // 手表快捷记录回调 → 写入本地
                    WatchSessionService.shared.onQuickLogReceived = { quickLog in
                        Task {
                            let day = cycleStore.day(for: quickLog.date) ?? CycleDay(date: quickLog.date)
                            day.flow = quickLog.flow
                            for code in quickLog.symptoms where !day.symptoms.contains(code) {
                                day.symptoms.append(code)
                            }
                            try? await cycleStore.upsert(day)
                        }
                    }
                    // CI 截图：按启动参数选择初始 Tab
                    applyLaunchTab()
                }
            } else {
                ProgressView()
                    .onAppear {
                        let store = CycleStore(modelContext: modelContext)
                        cycleStore = store
                        reportService = ReportService(modelContext: modelContext, cycleStore: store)
                    }
            }
        }
    }

    private func pushPredictionToWatch() {
        let prediction = PredictionEngine().predict(cycleStarts: cycleStore?.cycleStarts() ?? [])
        let summary = WatchSessionService.shared.summary(from: prediction, cycleStarts: cycleStore?.cycleStarts() ?? [])
        WatchSharedStorage.saveSummary(summary)
        WatchSessionService.shared.sendPredictionSummary(summary)
    }

    private var skipHealthAuthForScreenshots: Bool {
        LaunchArguments.skipHealthAuth
    }

    private func applyLaunchTab() {
        guard let tab = LaunchArguments.openTab else { return }
        switch tab {
        case "insights": selectedTab = .insights
        case "report": selectedTab = .report
        case "settings": selectedTab = .settings
        default: selectedTab = .calendar
        }
    }
}
