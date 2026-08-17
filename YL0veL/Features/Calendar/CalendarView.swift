import SwiftUI
import YL0veLPredictionKit

/// 月历视图：查看周期标记 + 选择日期编辑（记录核心入口）
@MainActor
struct CalendarView: View {
    @EnvironmentObject private var cycleStore: CycleStore
    @EnvironmentObject private var reportService: ReportService

    @State private var selectedDate = Calendar.current.startOfDay(for: .now)
    @State private var displayedMonth = Calendar.current.startOfDay(for: .now)
    @State private var editingDay: CycleDay?
    @State private var showVoiceRecord = false
    @State private var careFeedback: String?
    @State private var showQuickSMS = false

    private var prediction: CyclePrediction? {
        let starts = cycleStore.cycleStarts()
        return PredictionEngine().predict(cycleStarts: starts)
    }

    /// 今天是否处于经期（当天有记录 flow>0，或按周期规律推算在经期内）
    private var isPeriodToday: Bool {
        let today = Calendar.current.startOfDay(for: .now)
        if let day = cycleStore.day(for: today), day.flow > 0 {
            return true
        }
        guard let start = cycleStore.currentCycleStart else { return false }
        let cycleDay = (Calendar.current.dateComponents([.day], from: start, to: today).day ?? 0) + 1
        return cycleDay <= max(1, cycleStore.averagePeriodLength())
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if isPeriodToday {
                        periodCareBanner
                    }

                    PredictionCard(prediction: prediction)

                    monthCalendar

                    // 今日快捷操作
                    HStack(spacing: 12) {
                        quickActionButton("🩸", "记经期") {
                            let day = cycleStore.day(for: selectedDate) ?? CycleDay(date: selectedDate)
                            if day.flow == 0 { day.flow = FlowLevel.medium.rawValue }
                            editingDay = day
                        }
                        quickActionButton("🎙️", "语音记录") {
                            showVoiceRecord = true
                        }
                    }
                }
                .padding()
            }
            .background(YLTheme.softBackground)
            .navigationTitle("Y💗L")
            .alert(careFeedback ?? "", isPresented: Binding(get: { careFeedback != nil }, set: { if !$0 { careFeedback = nil } })) {
                Button("好", role: .cancel) {}
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        displayedMonth = Calendar.current.startOfDay(for: .now)
                        selectedDate = Calendar.current.startOfDay(for: .now)
                    } label: {
                        Image(systemName: "arrow.uturn.backward.circle")
                    }
                    .accessibilityLabel("回到今天")
                }
            }
            .sheet(item: $editingDay) { day in
                DayEditView(day: day, onSave: { updated in
                    Task {
                        try? await cycleStore.upsert(updated)
                        await NotificationService.shared.refreshPeriodReminderIfNeeded(cycleStore: cycleStore)
                        // 记录变化后检查周期报告（可能触发自动结束判定）
                        if let newReports = try? await reportService.checkAndGenerateReports(), !newReports.isEmpty {
                            await NotificationService.shared.scheduleReportReadyNotification(title: newReports.first?.title ?? "")
                        }
                    }
                })
            }
            .sheet(isPresented: $showVoiceRecord) {
                VoiceRecordView()
            }
            .sheet(isPresented: $showQuickSMS) {
                QuickSMSView()
            }
        }
    }

    // MARK: - 经期关爱横幅

    private var periodCareBanner: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "heart.fill")
                    .foregroundStyle(.white)
                Text("桃桃，这几天我都在，今天感觉怎么样？")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Spacer()
                Button {
                    showQuickSMS = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "paperplane.fill")
                            .font(.caption)
                        Text("告诉主人")
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(YLTheme.primaryDeep)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.white, in: Capsule())
                }
                .buttonStyle(.plain)
            }
            HStack(spacing: 10) {
                careButton("🔥", "热敷了") {
                    logCare("热敷了")
                    careFeedback = "记下啦，热敷完会舒服很多。我一直在。"
                    YVoicePlayer.shared.playScenario(.recordSaved)
                }
                careButton("🍵", "红糖水") {
                    logCare("喝了红糖水")
                    careFeedback = "红糖水记下啦，暖暖的，对肚子好。"
                    YVoicePlayer.shared.playScenario(.recordWater)
                }
                careButton("💊", "止痛药") {
                    logCare("吃了止痛药")
                    careFeedback = "记下啦。如果还是很疼，记得多休息，必要时看看医生。"
                    YVoicePlayer.shared.playScenario(.hug)
                }
            }
        }
        .padding(16)
        .background(
            LinearGradient(colors: [YLTheme.primary, YLTheme.primaryDeep], startPoint: .leading, endPoint: .trailing),
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
    }

    private func careButton(_ emoji: String, _ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(emoji)
                    .font(.caption)
                Text(title)
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(YLTheme.primaryDeep)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(.white, in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private func logCare(_ text: String) {
        let today = Calendar.current.startOfDay(for: .now)
        let day = cycleStore.day(for: today) ?? CycleDay(date: today)
        let line = "\(Date.now.formatted(date: .omitted, time: .shortened)) \(text)"
        day.diary = [day.diary, line].compactMap { $0 }.joined(separator: "\n")
        Task {
            try? await cycleStore.upsert(day)
        }
        YLTheme.hapticSuccess()
    }

    private func quickActionButton(_ emoji: String, _ title: String, action: @escaping () -> Void) -> some View {
        Button(action: {
            YLTheme.haptic()
            action()
        }) {
            VStack(spacing: 6) {
                Text(emoji).font(.system(size: 26))
                Text(title).font(.footnote.weight(.medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - 月历

    private var monthCalendar: some View {
        let days = daysInDisplayedMonth()
        let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

        return VStack(spacing: 12) {
            // 月份切换
            HStack {
                Button {
                    withAnimation(.spring(duration: 0.3, bounce: 0)) {
                        displayedMonth = month(offset: -1, from: displayedMonth)
                    }
                } label: {
                    Image(systemName: "chevron.left")
                }
                Spacer()
                Text(monthTitle(displayedMonth))
                    .font(.headline)
                Spacer()
                Button {
                    withAnimation(.spring(duration: 0.3, bounce: 0)) {
                        displayedMonth = month(offset: 1, from: displayedMonth)
                    }
                } label: {
                    Image(systemName: "chevron.right")
                }
            }
            .padding(.horizontal, 4)

            // 星期表头
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(["日", "一", "二", "三", "四", "五", "六"], id: \.self) { weekday in
                    Text(weekday)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            // 日期格子
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(days, id: \.self) { date in
                    DayCell(
                        date: date,
                        day: cycleStore.day(for: date),
                        isSelected: date == selectedDate,
                        isCurrentMonth: Calendar.current.isDate(date, equalTo: displayedMonth, toGranularity: .month),
                        isPredicted: prediction?.nextMensesWindow.contains(date) == true,
                        isOvulation: prediction?.estimatedOvulationWindow?.contains(date) == true
                    ) {
                        YLTheme.haptic(.light)
                        selectedDate = date
                    }
                }
            }
        }
        .ylCard()
    }

    private func daysInDisplayedMonth() -> [Date] {
        let calendar = Calendar.current
        let interval = calendar.dateInterval(of: .month, for: displayedMonth)!
        let firstWeekday = calendar.component(.weekday, from: interval.start)
        let leadingDays = (firstWeekday - calendar.firstWeekday + 7) % 7
        let start = calendar.date(byAdding: .day, value: -leadingDays, to: interval.start)!
        let totalDays = leadingDays + calendar.range(of: .day, in: .month, for: displayedMonth)!.count
        let trailingDays = (7 - totalDays % 7) % 7
        let count = totalDays + trailingDays
        return (0..<count).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    private func monthTitle(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年 M月"
        return formatter.string(from: date)
    }

    private func month(offset: Int, from date: Date) -> Date {
        Calendar.current.date(byAdding: .month, value: offset, to: date) ?? date
    }
}

/// 日期格子（记录状态：经血、预测窗口、排卵估计）
private struct DayCell: View {
    let date: Date
    let day: CycleDay?
    let isSelected: Bool
    let isCurrentMonth: Bool
    let isPredicted: Bool
    let isOvulation: Bool
    let onTap: () -> Void

    var body: some View {
        let calendar = Calendar.current
        let isToday = calendar.isDateInToday(date)
        let flow = FlowLevel(rawValue: day?.flow ?? 0) ?? .none

        Button(action: onTap) {
            VStack(spacing: 2) {
                Text("\(calendar.component(.day, from: date))")
                    .font(.system(size: 15, weight: isToday ? .bold : .regular, design: .rounded))
                    .foregroundStyle(isCurrentMonth ? .primary : .tertiary)
                    .frame(width: 32, height: 32)
                    .background {
                        if isSelected {
                            Circle().fill(YLTheme.primary.opacity(0.18))
                        }
                        if isToday && !isSelected {
                            Circle().stroke(YLTheme.primary.opacity(0.5), lineWidth: 1.5)
                        }
                        if flow != .none {
                            Circle().fill(YLTheme.flowColor(flow).opacity(0.85))
                        }
                    }
                    .overlay(alignment: .bottom) {
                        HStack(spacing: 2) {
                            if isPredicted {
                                Circle()
                                    .fill(YLTheme.primary)
                                    .frame(width: 5, height: 5)
                            }
                            if isOvulation {
                                Circle()
                                    .fill(Color.cyan)
                                    .frame(width: 5, height: 5)
                            }
                            // 症状密度小点（当日症状数 1~3+ → 1~3 个点）
                            let symptomCount = day?.symptoms.count ?? 0
                            if symptomCount > 0 && !isPredicted && !isOvulation {
                                ForEach(0..<min(3, symptomCount), id: \.self) { _ in
                                    Circle()
                                        .fill(Color.orange)
                                        .frame(width: 3.5, height: 3.5)
                                }
                            }
                        }
                        .offset(y: 18)
                    }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 3)
        }
        .buttonStyle(.plain)
    }
}
