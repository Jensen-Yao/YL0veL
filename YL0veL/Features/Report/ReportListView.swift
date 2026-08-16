import SwiftUI
import SwiftData

/// 周期报告列表（历史可翻阅）
struct ReportListView: View {
    @EnvironmentObject private var reportService: ReportService
    @EnvironmentObject private var cycleStore: CycleStore
    @State private var showManualEndConfirm = false
    @State private var showReportGenerated = false

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy年M月d日"
        return f
    }()

    var body: some View {
        NavigationStack {
            Group {
                if reportService.reports.isEmpty {
                    emptyState
                } else {
                    List {
                        Section {
                            ForEach(reportService.reports) { report in
                                NavigationLink {
                                    ReportDetailView(report: report)
                                } label: {
                                    ReportRow(report: report)
                                }
                            }
                        } footer: {
                            Text("每次经期结束后自动生成，保存完整历史，见证身体的变化规律 💗")
                                .font(.footnote)
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .background(YLTheme.softBackground)
            .navigationTitle("周期报告")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showManualEndConfirm = true
                    } label: {
                        Image(systemName: "plus.circle")
                    }
                    .accessibilityLabel("手动结束当前周期并生成报告")
                }
            }
            .confirmationDialog("手动结束当前周期？", isPresented: $showManualEndConfirm, titleVisibility: .visible) {
                Button("结束并生成报告") {
                    Task {
                        if try await reportService.manuallyEndCurrentCycle() != nil {
                            showReportGenerated = true
                            YLTheme.hapticSuccess()
                        }
                    }
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("将把当前进行中的周期标记为已结束，并立即生成周期报告。")
            }
            .alert("报告已生成 📋", isPresented: $showReportGenerated) {
                Button("好", role: .cancel) {}
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text("还没有周期报告")
                .font(.headline)
            Text(YPersona.Empty.noReport)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
}

private struct ReportRow: View {
    let report: CycleReport

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "M月d日"
        return f
    }()

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(report.title)
                    .font(.subheadline.weight(.semibold))
                Text("周期 \(report.cycleLength) 天 · 经期 \(report.periodLength) 天")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(Int(report.regularityScore))")
                .font(.headline)
                .foregroundStyle(scoreColor)
            Text("分")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    private var scoreColor: Color {
        switch report.regularityScore {
        case ..<55: return .gray
        case ..<85: return .orange
        default: return .green
        }
    }
}
