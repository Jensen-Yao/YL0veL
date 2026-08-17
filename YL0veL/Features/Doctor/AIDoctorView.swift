import SwiftUI
import SwiftData

/// AI 医生：向 AI 咨询身体状况与周期报告（需配置 API key）
@MainActor
struct AIDoctorView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \DoctorMessage.timestamp) private var messages: [DoctorMessage]

    @State private var inputText = ""
    @State private var isThinking = false

    private static let quickQuestions = [
        "我的报告怎么看？",
        "痛经怎么缓解？",
        "这个周期正常吗？",
        "经期头疼是什么原因？",
    ]

    private var llmConfig: LLMConfig? {
        let descriptor = FetchDescriptor<LLMConfig>()
        return (try? modelContext.fetch(descriptor).first).flatMap { $0.enabled ? $0 : nil }
    }

    var body: some View {
        VStack(spacing: 0) {
            // 免责横幅
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "cross.case.fill")
                    .foregroundStyle(.orange)
                Text("AI 建议仅供参考，不能替代医生诊断。紧急情况请及时就医。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(10)
            .background(Color.orange.opacity(0.08))

            if messages.isEmpty {
                welcomeView
            } else {
                messageList
            }

            questionChips
            inputBar
        }
        .background(YLTheme.softBackground)
        .navigationTitle("AI 医生")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var welcomeView: some View {
        VStack(spacing: 12) {
            Spacer()
            Text("🩺")
                .font(.system(size: 56))
            Text("把你的身体问题告诉我")
                .font(.headline)
            Text("结合你的周期报告，AI 医生会给出参考建议。\n可以先试试下面的问题。")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
            Spacer()
        }
        .padding(.horizontal, 32)
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(messages) { message in
                        DoctorBubble(message: message)
                            .id(message.id)
                    }
                    if isThinking {
                        HStack {
                            Text("正在思考…")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                        .padding(.leading, 4)
                    }
                }
                .padding()
                .onChange(of: messages.count) { _, _ in
                    if let last = messages.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }
        }
    }

    private var questionChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Text("试试问：")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                ForEach(Self.quickQuestions, id: \.self) { question in
                    Button {
                        inputText = question
                    } label: {
                        Text(question)
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.orange.opacity(0.1), in: Capsule())
                            .foregroundStyle(.orange)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .background(.regularMaterial.opacity(0.6))
    }

    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField("描述你的症状或问题…", text: $inputText, axis: .vertical)
                .lineLimit(1...4)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
            Button {
                send(inputText)
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(inputText.trimmingCharacters(in: .whitespaces).isEmpty ? .gray : .orange)
            }
            .buttonStyle(.plain)
            .disabled(inputText.trimmingCharacters(in: .whitespaces).isEmpty || isThinking)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.regularMaterial)
    }

    private func send(_ raw: String) {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isThinking else { return }
        inputText = ""
        saveMessage(role: "user", text: text)

        guard let config = llmConfig, let apiKey = KeychainService.read(key: config.apiKeyRef) else {
            saveMessage(role: "doctor", text: "还没有配置 AI 服务。请先在「设置 → AI 服务」里填好 API Key（DeepSeek 等），我才能帮你分析哦。")
            return
        }

        isThinking = true
        Task {
            do {
                let history = messages.suffix(8).map { (role: $0.role, content: $0.text) }
                let reply = try await LLMService.doctorChat(
                    userText: text,
                    history: history,
                    reportContext: latestReportContext(),
                    config: config,
                    apiKey: apiKey
                )
                saveMessage(role: "doctor", text: reply)
            } catch {
                saveMessage(role: "doctor", text: "抱歉，刚刚没有连接成功。请检查网络或 API Key 设置，再问我一次。")
            }
            isThinking = false
        }
    }

    private func latestReportContext() -> String {
        let descriptor = FetchDescriptor<CycleReport>(sortBy: [SortDescriptor(\.cycleStartDate, order: .reverse)])
        guard let report = try? modelContext.fetch(descriptor).first else { return "" }
        var parts: [String] = [
            "周期 \(report.cycleLength) 天，经期 \(report.periodLength) 天，规律性评分 \(Int(report.regularityScore))/100"
        ]
        let cramps = report.symptomCounts["cramps"] ?? 0
        if cramps > 0 { parts.append("痛经 \(cramps) 天") }
        let headache = report.symptomCounts["headache"] ?? 0
        if headache > 0 { parts.append("头痛 \(headache) 天") }
        if let hr = report.averageHeartRate { parts.append("平均静息心率 \(Int(hr)) 次/分") }
        if let sleep = report.averageSleepHours { parts.append(String(format: "平均睡眠 %.1f 小时", sleep)) }
        return parts.joined(separator: "；")
    }

    private func saveMessage(role: String, text: String) {
        let message = DoctorMessage(role: role, text: text)
        modelContext.insert(message)
        try? modelContext.save()
    }
}

/// AI 医生气泡
private struct DoctorBubble: View {
    let message: DoctorMessage

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.role == "doctor" {
                Image(systemName: "stethoscope.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(.orange)
                Text(message.text)
                    .font(.subheadline)
                    .padding(.horizontal, 13)
                    .padding(.vertical, 8)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                Spacer(minLength: 40)
            } else {
                Spacer(minLength: 40)
                Text(message.text)
                    .font(.subheadline)
                    .padding(.horizontal, 13)
                    .padding(.vertical, 8)
                    .foregroundStyle(.white)
                    .background(Color.orange.opacity(0.85), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            }
        }
    }
}
