import SwiftUI
import WidgetKit

/// Watch 表盘复杂功能（WidgetKit complication，watchOS 10+）：显示周期天数/距下次经期天数
/// 数据来源：App Group（iPhone/watch App 经 WCSession 收到后写入 WatchSharedStorage）
struct CycleComplication: Widget {
    let kind = "YL0veLCycleComplication"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CycleComplicationTimelineProvider()) { entry in
            CycleComplicationView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("YL0veL 周期")
        .description("表盘显示周期天数与经期预测")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryCorner])
    }
}

struct ComplicationEntry: TimelineEntry {
    let date: Date
    let cycleDayNumber: Int
    let daysUntilNextMenses: Int?
}

struct CycleComplicationTimelineProvider: TimelineProvider {

    func placeholder(in context: Context) -> ComplicationEntry {
        ComplicationEntry(date: .now, cycleDayNumber: 1, daysUntilNextMenses: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (ComplicationEntry) -> Void) {
        completion(currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ComplicationEntry>) -> Void) {
        // 每 30 分钟刷新；watch App 收到 iPhone 推送后会更新 App Group，刷新时读最新值
        let entry = currentEntry()
        let nextRefresh = Calendar.current.date(byAdding: .minute, value: 30, to: .now) ?? .now
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }

    private func currentEntry() -> ComplicationEntry {
        let summary = WatchSharedStorage.loadSummary()
        return ComplicationEntry(
            date: .now,
            cycleDayNumber: summary?.cycleDayNumber ?? 1,
            daysUntilNextMenses: summary?.daysUntilNextMenses
        )
    }
}

struct CycleComplicationView: View {
    let entry: ComplicationEntry
    @Environment(\.widgetFamily) private var family

    private let accent = Color(red: 0.95, green: 0.35, blue: 0.62)

    var body: some View {
        switch family {
        case .accessoryCircular:
            ZStack {
                Circle()
                    .fill(accent.opacity(0.15))
                VStack(spacing: 0) {
                    Text("D\(entry.cycleDayNumber)")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(accent)
                    if let days = entry.daysUntilNextMenses {
                        Text("\(days)天")
                            .font(.system(size: 8))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        case .accessoryRectangular:
            HStack(spacing: 8) {
                Image(systemName: "drop.fill")
                    .foregroundStyle(accent)
                VStack(alignment: .leading, spacing: 0) {
                    Text("周期第 \(entry.cycleDayNumber) 天")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                    if let days = entry.daysUntilNextMenses {
                        Text(days == 0 ? "经期今天开始 🌸" : "距下次经期 \(days) 天")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        case .accessoryCorner:
            VStack(spacing: 0) {
                Image(systemName: "drop.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(accent)
                if let days = entry.daysUntilNextMenses {
                    Text("\(days)")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                }
            }
        default:
            EmptyView()
        }
    }
}

/// Widget Extension 入口
@main
struct YL0veLWatchWidgets: WidgetBundle {
    var body: some Widget {
        CycleComplication()
    }
}
