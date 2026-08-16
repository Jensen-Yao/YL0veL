import SwiftUI
import YL0veLPredictionKit

/// 周期详情页：第 N 天时间线 + 相位说明 + 每日建议（管家 Y 视角）
@MainActor
struct CycleDetailView: View {
    @EnvironmentObject private var cycleStore: CycleStore

    private var currentCycleStart: Date? { cycleStore.currentCycleStart }
    private var averageCycleLength: Int { cycleStore.completedCycleDayCount() ?? 28 }
    private var periodLength: Int { cycleStore.averagePeriodLength() }

    private var cycleDayNumber: Int {
        guard let start = currentCycleStart else { return 1 }
        return (Calendar.current.dateComponents([.day], from: start, to: Calendar.current.startOfDay(for: .now)).day ?? 0) + 1
    }

    private var currentPhase: CyclePhase {
        CyclePhaseCalculator.phase(
            cycleDay: cycleDayNumber,
            cycleLength: averageCycleLength,
            periodLength: max(1, periodLength)
        )
    }

    private var nextPeriodEstimate: Date? {
        guard let start = currentCycleStart else { return nil }
        return Calendar.current.date(byAdding: .day, value: averageCycleLength, to: start)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // 今日状态卡
                    todayCard

                    // 相位说明卡
                    phaseCard

                    // 周期时间线
                    timelineCard

                    // 下次经期
                    nextPeriodCard
                }
                .padding()
            }
            .background(YLTheme.softBackground)
            .navigationTitle("周期")
        }
    }

    // MARK: - 今日状态

    private var todayCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(YPersona.Phase.emoji(currentPhase))
                    .font(.system(size: 34))
                VStack(alignment: .leading, spacing: 2) {
                    Text("今天是周期第 \(cycleDayNumber) 天")
                        .font(.title3.weight(.bold))
                    Text(YPersona.Phase.name(currentPhase))
                        .font(.subheadline)
                        .foregroundStyle(YLTheme.primary)
                }
                Spacer()
            }
            Text(YPersona.Phase.description(currentPhase))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .ylCard()
    }

    // MARK: - 相位说明

    private var phaseCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("管家 Y 的今日建议", systemImage: "sparkles")
                .font(.headline)
                .foregroundStyle(YLTheme.primary)
            Text(YPersona.Phase.advice(currentPhase))
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
        }
        .ylCard()
    }

    // MARK: - 周期时间线

    private var timelineCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("本周期时间线")
                .font(.headline)

            // 四个相位横条
            let segments = timelineSegments
            VStack(spacing: 0) {
                GeometryReader { proxy in
                    let total = CGFloat(max(1, averageCycleLength))
                    HStack(spacing: 0) {
                        ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                            let width = proxy.size.width * segment.days / total
                            VStack(spacing: 4) {
                                Text(segment.emoji)
                                    .font(.caption)
                                Text("\(segment.days)天")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(width: width, height: 40)
                            .background(segment.color.opacity(segment.isCurrent ? 0.9 : 0.35), in: RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
                .frame(height: 40)

                // 当前标记
                HStack {
                    Text("今天在「\(YPersona.Phase.name(currentPhase))」")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.top, 6)
            }

            Divider()

            // 各相位简述
            ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                HStack(alignment: .top, spacing: 8) {
                    Text(segment.emoji)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(segment.name)（约 \(segment.days) 天）")
                            .font(.footnote.weight(.semibold))
                        Text(segment.summary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .ylCard()
    }

    private struct TimelineSegment {
        let name: String
        let emoji: String
        let days: Int
        let color: Color
        let isCurrent: Bool
        let summary: String
    }

    private var timelineSegments: [TimelineSegment] {
        let ovulationDay = CyclePhaseCalculator.estimatedOvulationDay(cycleLength: averageCycleLength)
        let current = currentPhase
        return [
            TimelineSegment(
                name: "经期", emoji: "🩸", days: max(1, periodLength),
                color: YLTheme.primary,
                isCurrent: current == .menstrual,
                summary: "身体休整期，注意保暖"
            ),
            TimelineSegment(
                name: "卵泡期", emoji: "🌱", days: max(1, ovulationDay - 2 - max(1, periodLength)),
                color: .green,
                isCurrent: current == .follicular,
                summary: "状态回升，适合运动"
            ),
            TimelineSegment(
                name: "排卵期", emoji: "✨", days: 4,
                color: .cyan,
                isCurrent: current == .ovulation,
                summary: "状态最佳，魅力拉满"
            ),
            TimelineSegment(
                name: "黄体期", emoji: "🌙", days: max(1, averageCycleLength - ovulationDay - 1),
                color: .orange,
                isCurrent: current == .luteal,
                summary: "情绪敏感期，早点休息"
            ),
        ]
    }

    // MARK: - 下次经期

    private var nextPeriodCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("下次经期", systemImage: "calendar.badge.clock")
                .font(.headline)
            if let next = nextPeriodEstimate {
                let daysLeft = Calendar.current.dateComponents([.day], from: .now, to: next).day ?? 0
                Text(daysLeft <= 0
                     ? "桃桃，经期可能已经到访啦，管家 Y 在呢 💗"
                     : "预计还有 \(daysLeft) 天，\(YPersona.dayFormatter.string(from: next)) 前后。管家 Y 会提前提醒你准备 🌸")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("再多记录几个周期，管家 Y 就能告诉你啦 🌱")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .ylCard()
    }
}
