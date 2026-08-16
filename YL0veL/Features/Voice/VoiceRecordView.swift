import SwiftUI
import SwiftData

/// 语音对话记录：一句话 → 规则/LLM 解析 → 预览确认卡 → 写入
@MainActor
struct VoiceRecordView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var cycleStore: CycleStore

    @StateObject private var speech = SpeechService()
    @State private var text = ""
    @State private var draft: RecordDraft?
    @State private var parsing = false
    @State private var errorMessage: String?
    @State private var saveSuccess = false

    /// 记录例句
    private static let recordExamples = [
        "今天来了，量少",
        "昨天来的，肚子疼",
        "今天没来，就是心情不好",
        "昨晚没睡好",
        "今天头疼，有点恶心",
    ]

    private var llmConfig: LLMConfig? {
        let descriptor = FetchDescriptor<LLMConfig>()
        return (try? modelContext.fetch(descriptor).first).flatMap { $0.enabled ? $0 : nil }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // 麦克风可视化
                ZStack {
                    Circle()
                        .fill(YLTheme.primary.opacity(speech.isRecording ? 0.22 : 0.08))
                        .frame(width: 140, height: 140)
                        .scaleEffect(speech.isRecording ? 1.06 : 1.0)
                        .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: speech.isRecording)

                    Button {
                        toggleRecording()
                    } label: {
                        Image(systemName: speech.isRecording ? "stop.fill" : "mic.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(.white)
                            .frame(width: 88, height: 88)
                            .background(YLTheme.brandGradient, in: Circle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 24)

                Text(speech.isRecording ? "正在聆听…" : "点击麦克风开始")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                // 例句引导：让桃桃知道怎么说才准确
                VStack(alignment: .leading, spacing: 8) {
                    Text("试试这样说：")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Self.recordExamples, id: \.self) { example in
                                Button {
                                    text = example
                                } label: {
                                    Text(example)
                                        .font(.caption)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(YLTheme.primary.opacity(0.08), in: Capsule())
                                        .foregroundStyle(YLTheme.primary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(.horizontal)

                // 实时转写 + 可编辑
                TextField("也可以直接打字输入", text: $text, axis: .vertical)
                    .lineLimit(2...5)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal)
                    .onChange(of: speech.liveTranscript) { _, newValue in
                        if speech.isRecording { text = newValue }
                    }

                if parsing {
                    ProgressView("解析中…")
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .padding(.horizontal)
                }

                // 预览确认卡
                if let draft {
                    DraftPreviewCard(draft: draft) {
                        Task { await save(draft) }
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.97)))
                }

                Spacer()

                if !text.isEmpty && draft == nil {
                    Button("解析") {
                        parseText()
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(YLTheme.brandGradient, in: Capsule())
                    .foregroundStyle(.white)
                    .buttonStyle(.plain)
                    .padding(.horizontal)
                }
            }
            .navigationTitle("语音记录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            .alert("已记录 💗", isPresented: $saveSuccess) {
                Button("好") { dismiss() }
            }
        }
    }

    private func toggleRecording() {
        if speech.isRecording {
            speech.stop()
            return
        }
        Task {
            let authorized = await speech.requestAuthorization()
            guard authorized else {
                errorMessage = "未获得语音识别权限，请在系统设置中开启"
                return
            }
            do {
                try speech.start(onResult: { finalText in
                    text = finalText
                    parseText()
                }, onError: { error in
                    errorMessage = error.localizedDescription
                })
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    /// 解析：规则引擎优先（离线），失败且有 LLM 配置时走 LLM
    private func parseText() {
        let input = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { return }
        parsing = true
        errorMessage = nil

        let parser = RecordParser(today: .now)
        if let local = parser.parse(input) {
            withAnimation(.spring(duration: 0.35, bounce: 0)) {
                draft = local
            }
            parsing = false
            return
        }

        // 规则失败 → LLM
        guard let config = llmConfig, let apiKey = KeychainService.read(key: config.apiKeyRef) else {
            errorMessage = "没有识别出可记录的内容，试试「今天来了，量少肚子疼」或配置 AI 服务增强理解"
            parsing = false
            return
        }

        Task {
            do {
                var context: LLMService.CycleContext? = nil
                if config.includeCycleContext, let start = cycleStore.currentCycleStart {
                    let dayNumber = (Calendar.current.dateComponents([.day], from: start, to: .now).day ?? 0) + 1
                    let average = cycleStore.completedCycleDayCount() ?? 28
                    context = LLMService.CycleContext(cycleDayNumber: dayNumber, averageCycleLength: average, lastPeriodStart: start)
                }
                let result = try await LLMService.extractRecordDraft(from: input, today: .now, config: config, apiKey: apiKey, cycleContext: context)
                draft = result
                parsing = false
            } catch {
                errorMessage = "AI 解析失败：\(error.localizedDescription)，已退回手动输入"
                parsing = false
            }
        }
    }

    private func save(_ draft: RecordDraft) async {
        let date = draft.date ?? Calendar.current.startOfDay(for: .now)
        let day = cycleStore.day(for: date) ?? CycleDay(date: date)
        if let flow = draft.flow { day.flow = flow }
        for code in draft.symptoms where !day.symptoms.contains(code) {
            day.symptoms.append(code)
        }
        if let mood = draft.mood { day.mood = mood }
        if let note = draft.note, !note.isEmpty { day.note = note }
        try? await cycleStore.upsert(day)
        YLTheme.hapticSuccess()
        saveSuccess = true
    }
}

/// 解析预览确认卡（可修改字段后保存）
struct DraftPreviewCard: View {
    let draft: RecordDraft
    let onConfirm: () -> Void

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "M月d日"
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("确认记录")
                .font(.headline)

            if let date = draft.date {
                Label(dateFormatter.string(from: date), systemImage: "calendar")
                    .font(.subheadline)
            }
            if let flow = draft.flow, flow > 0 {
                Label("经血量：\(FlowLevel(rawValue: flow)?.displayName ?? "")", systemImage: "drop.fill")
                    .font(.subheadline)
            }
            if !draft.symptoms.isEmpty {
                Label("症状：\(draft.symptoms.map { SymptomCatalog.painName(forCode: $0) }.joined(separator: "、"))", systemImage: "bandage")
                    .font(.subheadline)
            }
            if let mood = draft.mood {
                Label("情绪：\(SymptomCatalog.moodName(forCode: mood))", systemImage: "face.smiling")
                    .font(.subheadline)
            }

            Button(action: onConfirm) {
                Text("保存")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(YLTheme.primary, in: Capsule())
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
        }
        .ylCard()
        .padding(.horizontal)
    }
}
