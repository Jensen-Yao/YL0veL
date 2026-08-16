import SwiftUI
import WidgetKit

/// Watch 首页：周期信息 + 快捷记录 + 健康摘要卡
struct WatchHomeView: View {
    @EnvironmentObject private var session: WatchSessionService
    @EnvironmentObject private var health: WatchHealthService

    @State private var showQuickLog = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    predictionCard
                    healthCard
                    quickActions
                }
            }
            .navigationTitle("Y💗L")
            .sheet(isPresented: $showQuickLog) {
                WatchQuickLogView()
            }
            .task {
                await health.refreshLatestMetrics()
            }
        }
    }

    private var predictionCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("周期第 \(session.summary?.cycleDayNumber ?? 1) 天")
                .font(.headline)
            if let days = session.summary?.daysUntilNextMenses, days >= 0 {
                Text(days == 0 ? "经期预计今天开始 🌸" : "距下次经期约 \(days) 天")
                    .font(.subheadline)
                    .foregroundStyle(YLWatchTheme.primary)
            } else {
                Text("等待 iPhone 同步预测…")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(YLWatchTheme.primary.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(.horizontal)
    }

    private var healthCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("今日健康")
                .font(.headline)
            HStack(spacing: 10) {
                if let hr = health.latestHeartRate {
                    Label("\(Int(hr))", systemImage: "heart.fill")
                        .font(.caption2)
                        .foregroundStyle(.red)
                }
                if let hrv = health.latestHRV {
                    Label("\(Int(hrv))ms", systemImage: "waveform.path.ecg")
                        .font(.caption2)
                        .foregroundStyle(.green)
                }
                if let sleep = health.lastNightSleepHours {
                    Label(String(format: "%.1fh", sleep), systemImage: "bed.double.fill")
                        .font(.caption2)
                        .foregroundStyle(.indigo)
                }
                if health.latestHeartRate == nil && health.latestHRV == nil && health.lastNightSleepHours == nil {
                    Text("佩戴入睡后自动记录")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(.horizontal)
    }

    private var quickActions: some View {
        HStack(spacing: 10) {
            Button {
                showQuickLog = true
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "drop.fill")
                        .font(.title3)
                    Text("记经期")
                        .font(.caption2)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(YLWatchTheme.primary.opacity(0.15), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal)
    }
}

enum YLWatchTheme {
    static let primary = Color(red: 0.95, green: 0.35, blue: 0.62)
}

/// 快捷记录：一键经血 + 常见症状
struct WatchQuickLogView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var session: WatchSessionService

    @State private var flow = FlowLevel.medium.rawValue
    @State private var cramps = false
    @State private var headache = false
    @State private var saved = false

    var body: some View {
        VStack(spacing: 12) {
            Text("快速记录")
                .font(.headline)

            Picker("经血量", selection: $flow) {
                ForEach([FlowLevel.light, FlowLevel.medium, FlowLevel.heavy], id: \.rawValue) { level in
                    Text(level.displayName).tag(level.rawValue)
                }
            }
            .pickerStyle(.navigationLink)

            Toggle("痛经", isOn: $cramps)
            Toggle("头痛", isOn: $headache)

            Button {
                var symptoms: [String] = []
                if cramps { symptoms.append("cramps") }
                if headache { symptoms.append("headache") }
                session.sendQuickLog(date: .now, flow: flow, symptoms: symptoms)
                saved = true
            } label: {
                Text("保存")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(YLWatchTheme.primary, in: Capsule())
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .alert("已记录 💗", isPresented: $saved) {
            Button("好") { dismiss() }
        }
    }
}
