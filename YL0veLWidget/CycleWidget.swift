import SwiftUI
import WidgetKit

/// iPhone 小组件：周期天数 + 距下次经期倒计时
struct CycleWidget: Widget {
    let kind = "YL0veLCycleWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CycleWidgetTimelineProvider()) { entry in
            CycleWidgetView(entry: entry)
                .containerBackground(Color(red: 1.0, green: 0.96, blue: 0.98), for: .widget)
        }
        .configurationDisplayName("YL0veL 周期")
        .description("主屏幕与锁屏显示周期天数与经期预测")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular])
    }
}

struct CycleWidgetEntry: TimelineEntry {
    let date: Date
    let cycleDayNumber: Int
    let daysUntilNextMenses: Int?
    let windowText: String?
}

struct CycleWidgetTimelineProvider: TimelineProvider {

    func placeholder(in context: Context) -> CycleWidgetEntry {
        CycleWidgetEntry(date: .now, cycleDayNumber: 1, daysUntilNextMenses: nil, windowText: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (CycleWidgetEntry) -> Void) {
        completion(currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CycleWidgetEntry>) -> Void) {
        let entry = currentEntry()
        let nextRefresh = Calendar.current.date(byAdding: .hour, value: 1, to: .now) ?? .now
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }

    private func currentEntry() -> CycleWidgetEntry {
        let summary = WatchSharedStorage.loadSummary()
        var windowText: String?
        if let start = summary?.nextWindowStart, let end = summary?.nextWindowEnd {
            let formatter = DateFormatter()
            formatter.dateFormat = "M/d"
            windowText = "\(formatter.string(from: start))~\(formatter.string(from: end))"
        }
        return CycleWidgetEntry(
            date: .now,
            cycleDayNumber: summary?.cycleDayNumber ?? 1,
            daysUntilNextMenses: summary?.daysUntilNextMenses,
            windowText: windowText
        )
    }
}

struct CycleWidgetView: View {
    let entry: CycleWidgetEntry
    @Environment(\.widgetFamily) private var family

    private let accent = Color(red: 0.95, green: 0.35, blue: 0.62)

    var body: some View {
        switch family {
        case .systemSmall:
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "drop.fill")
                        .foregroundStyle(accent)
                    Text("Y💗L")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                }
                Text("周期第 \(entry.cycleDayNumber) 天")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                if let days = entry.daysUntilNextMenses {
                    Text(days == 0 ? "经期今天开始 🌸" : "距下次经期 \(days) 天")
                        .font(.system(size: 13))
                        .foregroundStyle(accent)
                } else {
                    Text("数据积累中")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                if let windowText = entry.windowText {
                    Text(windowText)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        case .systemMedium:
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: "drop.fill")
                            .foregroundStyle(accent)
                        Text("Y💗L")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                    }
                    Text("周期第 \(entry.cycleDayNumber) 天")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                    if let days = entry.daysUntilNextMenses {
                        Text(days == 0 ? "经期预计今天开始 🌸" : "距下次经期约 \(days) 天")
                            .font(.system(size: 14))
                            .foregroundStyle(accent)
                    }
                }
                Spacer()
                if let windowText = entry.windowText {
                    VStack(spacing: 2) {
                        Text("预测窗口")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(windowText)
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(accent)
                    }
                    .padding(10)
                    .background(accent.opacity(0.1), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
        case .accessoryCircular:
            VStack(spacing: 2) {
                Image(systemName: "drop.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(accent)
                if let days = entry.daysUntilNextMenses {
                    Text("\(days)")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(accent)
                } else {
                    Text("D\(entry.cycleDayNumber)")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                }
            }
        case .accessoryRectangular:
            HStack(spacing: 6) {
                Image(systemName: "drop.fill")
                    .foregroundStyle(accent)
                VStack(alignment: .leading, spacing: 0) {
                    Text("周期第 \(entry.cycleDayNumber) 天")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                    if let days = entry.daysUntilNextMenses {
                        Text(days == 0 ? "经期今天开始 🌸" : "距下次经期 \(days) 天")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        default:
            EmptyView()
        }
    }
}

@main
struct YL0veLWidgets: WidgetBundle {
    var body: some Widget {
        CycleWidget()
    }
}
