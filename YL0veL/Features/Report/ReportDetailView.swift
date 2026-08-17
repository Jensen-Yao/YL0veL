import SwiftUI
import Charts

/// 周期报告详情（App 内阅读；可分享为 PDF/图片）
struct ReportDetailView: View {
    let report: CycleReport

    @State private var renderedImage: UIImage?
    @State private var reportImageData: Data?
    @State private var pdfURL: URL?

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy年M月d日"
        return f
    }()

    var body: some View {
        ScrollView {
            reportContent
                .padding()
        }
        .background(YLTheme.softBackground)
        .navigationTitle("周期报告")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    readReport()
                } label: {
                    Image(systemName: "speaker.wave.2")
                }
                .accessibilityLabel("念给桃桃听")
            }
            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(
                    item: pdfURL ?? URL(fileURLWithPath: "/"),
                    preview: SharePreview("YL0veL 周期报告 PDF")
                ) {
                    Image(systemName: "doc.richtext")
                }
                .accessibilityLabel("导出 PDF 分享")
                .disabled(pdfURL == nil)
            }
            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(
                    item: reportImageData ?? Data(),
                    preview: SharePreview("YL0veL 周期报告", image: Image(uiImage: renderedImage ?? UIImage()))
                ) {
                    Image(systemName: "square.and.arrow.up")
                }
                .disabled(reportImageData == nil)
            }
        }
        .task {
            renderedImage = await renderReport()
            reportImageData = renderedImage?.pngData()
            pdfURL = generatePDF()
        }
    }

    // MARK: - PDF 导出（简洁医疗摘要，分享给医生）

    private func generatePDF() -> URL? {
        let format = UIGraphicsPDFRendererFormat()
        let pageRect = CGRect(x: 0, y: 0, width: 595, height: 842)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)

        let data = renderer.pdfData { context in
            context.beginPage()
            var y: CGFloat = 60
            let margin: CGFloat = 48

            func drawText(_ text: String, size: CGFloat, bold: Bool, color: UIColor = .black) {
                let font = bold ? UIFont.boldSystemFont(ofSize: size) : UIFont.systemFont(ofSize: size)
                let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
                text.draw(at: CGPoint(x: margin, y: y), withAttributes: attrs)
                y += size + 10
            }

            drawText("YL0veL 周期报告", size: 24, bold: true, color: UIColor(red: 0.95, green: 0.35, blue: 0.62, alpha: 1))
            drawText(report.title, size: 14, bold: false, color: .darkGray)
            y += 14

            drawText("周期概况", size: 16, bold: true)
            drawText("周期长度：\(report.cycleLength) 天", size: 13, bold: false)
            drawText("经期长度：\(report.periodLength) 天", size: 13, bold: false)
            let flowText = report.flowDistribution
                .sorted { $0.value > $1.value }
                .map { "\($0.key) \($0.value) 天" }
                .joined(separator: "、")
            drawText("流量分布：\(flowText.isEmpty ? "—" : flowText)", size: 13, bold: false)
            y += 10

            drawText("症状统计", size: 16, bold: true)
            let symptoms = report.symptomCounts
                .sorted { $0.value > $1.value }
                .prefix(5)
                .map { "\(SymptomCatalog.painName(forCode: $0.key)) \($0.value) 天" }
                .joined(separator: "、")
            drawText(symptoms.isEmpty ? "无显著症状记录" : symptoms, size: 13, bold: false)
            y += 10

            drawText("健康趋势", size: 16, bold: true)
            if let hr = report.averageHeartRate {
                drawText("平均静息心率：\(String(format: "%.0f", hr)) 次/分", size: 13, bold: false)
            }
            if let hrv = report.averageHRV {
                drawText("平均 HRV：\(String(format: "%.0f", hrv)) ms", size: 13, bold: false)
            }
            if let sleep = report.averageSleepHours {
                drawText("平均睡眠：\(String(format: "%.1f", sleep)) 小时", size: 13, bold: false)
            }
            if report.averageHeartRate == nil && report.averageHRV == nil && report.averageSleepHours == nil {
                drawText("暂无设备健康数据", size: 13, bold: false, color: .gray)
            }
            y += 10

            drawText("规律性评分：\(Int(report.regularityScore)) / 100", size: 14, bold: true)
            y += 20

            drawText("本报告由 YL0veL 自动生成，仅供参考，不构成医疗建议。", size: 11, bold: false, color: .gray)
        }

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("YL0veL-周期报告-\(report.title).pdf")
        try? data.write(to: url)
        return url
    }

    /// 报告朗读：按报告内容拼语音包片段顺序播放（语音未开启时静默）
    private func readReport() {
        var scenarios: [YVoicePlayer.Scenario] = [.reportReady]
        let crampDays = report.symptomCounts["cramps"] ?? 0
        if report.regularityScore >= 85 && crampDays == 0 {
            scenarios.append(.reportPraise)
        } else if crampDays > 0 {
            scenarios.append(.reportCrampsCare)
        } else {
            scenarios.append(.reportComfort)
        }
        YVoicePlayer.shared.playSequence(scenarios)
    }

    // MARK: - 报告内容

    private var reportContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            // 头部
            VStack(spacing: 6) {
                Text("Y💗L 周期报告")
                    .font(.title2.weight(.bold))
                Text(report.title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if let end = report.cycleEndDate {
                    Text("\(dateFormatter.string(from: report.cycleStartDate)) ~ \(dateFormatter.string(from: end))")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                scoreRing
                    .padding(.top, 6)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 12)

            // 周期概况
            sectionCard("周期概况") {
                overviewRow(label: "周期长度", value: "\(report.cycleLength) 天")
                overviewRow(label: "经期长度", value: "\(report.periodLength) 天")
                if !report.flowDistribution.isEmpty {
                    Divider()
                    Text("流量分布")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 10) {
                        ForEach(FlowLevel.allCases.filter { report.flowDistribution[$0.displayName] != nil }, id: \.rawValue) { level in
                            let days = report.flowDistribution[level.displayName] ?? 0
                            VStack(spacing: 4) {
                                Text(level.emoji).font(.title3)
                                Text("\(days) 天").font(.caption2)
                                Text(level.displayName).font(.caption2).foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(YLTheme.flowColor(level).opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }
            }

            // 症状与情绪
            if !report.symptomCounts.isEmpty || !report.moodCounts.isEmpty {
                sectionCard("症状与情绪") {
                    if !report.symptomCounts.isEmpty {
                        Text("高频症状")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        ForEach(sortedSymptomCounts.prefix(5), id: \.code) { item in
                            barRow(label: SymptomCatalog.painName(forCode: item.code), count: item.count, total: report.periodLength)
                        }
                    }
                    if !report.moodCounts.isEmpty {
                        Divider()
                        Text("情绪")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        ForEach(sortedMoodCounts.prefix(3), id: \.code) { item in
                            barRow(label: SymptomCatalog.moodName(forCode: item.code), count: item.count, total: report.periodLength)
                        }
                    }
                }
            }

            // 健康趋势
            if hasHealthMetrics {
                sectionCard("健康趋势（Apple Watch）") {
                    if let hr = report.averageHeartRate {
                        overviewRow(label: "平均静息心率", value: String(format: "%.0f 次/分", hr))
                    }
                    if let hrv = report.averageHRV {
                        overviewRow(label: "平均 HRV", value: String(format: "%.0f ms", hrv))
                    }
                    if let sleep = report.averageSleepHours {
                        overviewRow(label: "平均睡眠", value: String(format: "%.1f 小时", sleep))
                    }
                    if let temp = report.averageWristTemperatureDeviation {
                        overviewRow(label: "手腕温度偏离", value: String(format: "%+.2f ℃", temp))
                    }
                    Text("随周期相位自然波动，仅供参考")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            // 对比
            sectionCard("与上个周期对比") {
                Text(report.comparisonSummary)
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // 关怀
            VStack(alignment: .leading, spacing: 10) {
                Label("Y💗L 的关怀", systemImage: "heart.fill")
                    .font(.headline)
                    .foregroundStyle(YLTheme.primary)
                Text(report.careMessage)
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .ylCard()

            // 免责
            Text("本报告由个人记录与统计模型自动生成，仅供参考，不构成医疗建议。如有不适请咨询专业医生。")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private var hasHealthMetrics: Bool {
        report.averageHeartRate != nil || report.averageHRV != nil
            || report.averageSleepHours != nil || report.averageWristTemperatureDeviation != nil
    }

    private var sortedSymptomCounts: [(code: String, count: Int)] {
        report.symptomCounts.map { (code: $0.key, count: $0.value) }.sorted { $0.count > $1.count }
    }

    private var sortedMoodCounts: [(code: String, count: Int)] {
        report.moodCounts.map { (code: $0.key, count: $0.value) }.sorted { $0.count > $1.count }
    }

    // MARK: - 组件

    private var scoreRing: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.15), lineWidth: 10)
                .frame(width: 92, height: 92)
            Circle()
                .trim(from: 0, to: report.regularityScore / 100)
                .stroke(scoreColor, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: 92, height: 92)
            VStack(spacing: 0) {
                Text("\(Int(report.regularityScore))")
                    .font(.title2.weight(.bold))
                Text("规律分")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var scoreColor: Color {
        switch report.regularityScore {
        case ..<55: return .gray
        case ..<85: return .orange
        default: return .green
        }
    }

    private func sectionCard(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
            content()
        }
        .ylCard()
    }

    private func overviewRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.semibold))
        }
    }

    private func barRow(label: String, count: Int, total: Int) -> some View {
        HStack(spacing: 10) {
            Text(label)
                .font(.footnote)
                .frame(width: 72, alignment: .leading)
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.gray.opacity(0.12))
                    Capsule()
                        .fill(YLTheme.primary.opacity(0.6))
                        .frame(width: proxy.size.width * min(1, Double(count) / Double(max(1, total))))
                }
            }
            .frame(height: 8)
            Text("\(count) 天")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(width: 36, alignment: .trailing)
        }
    }

    // MARK: - 渲染分享

    @MainActor
    private func renderReport() async -> UIImage? {
        let renderer = ImageRenderer(content: reportContent.padding(20).background(YLTheme.softBackground))
        renderer.scale = UIScreen.main.scale
        return renderer.uiImage
    }
}
