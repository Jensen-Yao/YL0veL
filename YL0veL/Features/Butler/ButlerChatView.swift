import SwiftUI
import SwiftData
import YL0veLPredictionKit

/// 管家 Y 页：状态卡 + 功能入口 + 对话记录（简洁、功能优先）
@MainActor
struct ButlerChatView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var cycleStore: CycleStore
    @EnvironmentObject private var appState: AppState

    @Query(sort: \ButlerMessage.timestamp) private var messages: [ButlerMessage]

    @State private var inputText = ""
    @State private var isThinking = false
    @State private var editingToday: CycleDay?
    @StateObject private var speech = SpeechService()

    /// 记录例句（让桃桃知道怎么说）
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
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 14) {
                        statusCard
                        quickActions
                        chatArea
                    }
                    .padding()
                }

                exampleChips
                inputBar
            }
            .background(YLTheme.softBackground)
            .navigationTitle("管家 Y")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("设置")
                }
            }
            .sheet(item: $editingToday) { day in
                DayEditView(day: day, onSave: { updated in
                    Task {
                        try? await cycleStore.upsert(updated)
                        await NotificationService.shared.refreshPeriodReminderIfNeeded(cycleStore: cycleStore)
                        deliver(reply: YPersona.RecordFeedback.saved(
                            hasCramps: updated.symptoms.contains("cramps"),
                            hasFlow: updated.flow > 0
                        ), scenario: updated.symptoms.contains("cramps") ? .recordSavedCramps : .recordSaved)
                    }
                })
            }
        }
    }

    // MARK: - 状态卡（简洁）

    private var statusCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 34))
                .foregroundStyle(YLTheme.primary)
            VStack(alignment: .leading, spacing: 3) {
                Text(statusTitle)
                    .font(.subheadline.weight(.semibold))
                Text(statusDetail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var statusTitle: String {
        guard let start = cycleStore.currentCycleStart else {
            return "管家 Y 待命中"
        }
        let day = (Calendar.current.dateComponents([.day], from: start, to: .now).day ?? 0) + 1
        let phase = CyclePhaseCalculator.phase(
            cycleDay: day,
            cycleLength: cycleStore.completedCycleDayCount() ?? 28,
            periodLength: max(1, cycleStore.averagePeriodLength())
        )
        return "周期第 \(day) 天 · \(YPersona.Phase.name(phase))"
    }

    private var statusDetail: String {
        let prediction = PredictionEngine().predict(cycleStarts: cycleStore.cycleStarts())
        guard let next = prediction?.nextMensesWindow.first else {
            return "记录更多周期后，管家 Y 可以预测经期"
        }
        let days = Calendar.current.dateComponents([.day], from: .now, to: next).day ?? 0
        if days <= 0 {
            return "经期可能已到访，注意休息"
        }
        return "距下次经期约 \(days) 天（\(YPersona.dayFormatter.string(from: next)) 前后）"
    }

    // MARK: - 快捷功能入口

    private var quickActions: some View {
        HStack(spacing: 10) {
            quickAction(icon: "drop.fill", title: "记经期") {
                let today = Calendar.current.startOfDay(for: .now)
                let day = cycleStore.day(for: today) ?? CycleDay(date: today)
                editingToday = day
            }
            NavigationLink {
                ReportListView()
            } label: {
                quickActionLabel(icon: "doc.text.fill", title: "周期报告")
            }
            NavigationLink {
                ChecklistEditorView(checklist: appState.settings?.checklist ?? []) { updated in
                    appState.settings?.checklist = updated
                    try? modelContext.save()
                }
            } label: {
                quickActionLabel(icon: "checklist", title: "准备清单")
            }
            NavigationLink {
                InsightsView()
            } label: {
                quickActionLabel(icon: "chart.xyaxis.line", title: "趋势洞察")
            }
        }
    }

    private func quickAction(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button {
            YLTheme.haptic(.light)
            action()
        } label: {
            quickActionLabel(icon: icon, title: title)
        }
        .buttonStyle(.plain)
    }

    private func quickActionLabel(icon: String, title: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(YLTheme.primary)
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - 聊天区

    @ViewBuilder
    private var chatArea: some View {
        if messages.isEmpty {
            VStack(spacing: 8) {
                Text("桃桃，我在。")
                    .font(.subheadline.weight(.semibold))
                Text("想记录就点「记经期」，或直接在下面告诉我；\n想看数据就点上面的入口。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 28)
        } else {
            ScrollViewReader { proxy in
                LazyVStack(spacing: 10) {
                    ForEach(messages) { message in
                        MessageBubble(message: message)
                            .id(message.id)
                    }
                    if isThinking {
                        HStack {
                            Text("正在想…")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                        .padding(.leading, 4)
                    }
                }
                .onChange(of: messages.count) { _, _ in
                    if let last = messages.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }
        }
    }

    // MARK: - 记录例句引导

    private var exampleChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Text("试试这样说：")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                ForEach(Self.recordExamples, id: \.self) { example in
                    Button {
                        inputText = example
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
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .background(.regularMaterial.opacity(0.6))
    }

    // MARK: - 输入栏

    private var inputBar: some View {
        HStack(spacing: 10) {
            Button {
                toggleVoiceInput()
            } label: {
                Image(systemName: speech.isRecording ? "stop.circle.fill" : "mic.circle")
                    .font(.system(size: 26))
                    .foregroundStyle(speech.isRecording ? .red : YLTheme.primary)
            }
            .buttonStyle(.plain)

            TextField("告诉管家 Y…", text: $inputText, axis: .vertical)
                .lineLimit(1...4)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
                .onChange(of: speech.liveTranscript) { _, newValue in
                    if speech.isRecording { inputText = newValue }
                }

            Button {
                send(inputText)
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(inputText.trimmingCharacters(in: .whitespaces).isEmpty ? .gray : YLTheme.primary)
            }
            .buttonStyle(.plain)
            .disabled(inputText.trimmingCharacters(in: .whitespaces).isEmpty || isThinking)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.regularMaterial)
    }

    // MARK: - 语音输入

    private func toggleVoiceInput() {
        if speech.isRecording {
            speech.stop()
            return
        }
        Task {
            let authorized = await speech.requestAuthorization()
            guard authorized else { return }
            do {
                try speech.start(onResult: { finalText in
                    inputText = finalText
                    send(finalText)
                }, onError: { _ in })
            } catch {}
        }
    }

    // MARK: - 发送与回复

    private func send(_ raw: String) {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isThinking else { return }
        inputText = ""
        saveMessage(role: "user", text: text)
        YLTheme.haptic(.light)

        // 1) 记录意图：离线规则解析优先
        let parser = RecordParser(today: .now)
        if let draft = parser.parse(text), !draft.isEmpty {
            handleRecordDraft(draft, original: text)
            return
        }

        // 2) LLM 管家回复（配 key 时）
        if let config = llmConfig, let apiKey = KeychainService.read(key: config.apiKeyRef) {
            isThinking = true
            Task {
                do {
                    var context: LLMService.CycleContext? = nil
                    if config.includeCycleContext, let start = cycleStore.currentCycleStart {
                        let dayNumber = (Calendar.current.dateComponents([.day], from: start, to: .now).day ?? 0) + 1
                        context = LLMService.CycleContext(
                            cycleDayNumber: dayNumber,
                            averageCycleLength: cycleStore.completedCycleDayCount() ?? 28,
                            lastPeriodStart: start
                        )
                    }
                    let history = messages.suffix(10).map { (role: $0.role, content: $0.text) }
                    let reply = try await LLMService.butlerChat(
                        userText: text,
                        history: history,
                        cycleContext: context,
                        config: config,
                        apiKey: apiKey
                    )
                    deliver(reply: reply, scenario: nil)
                } catch {
                    let fallback = templateReply(text)
                    deliver(reply: fallback.reply, scenario: fallback.scenario)
                }
                isThinking = false
            }
            return
        }

        // 3) 模板兜底（无 key）
        let fallback = templateReply(text)
        deliver(reply: fallback.reply, scenario: fallback.scenario)
    }

    private func handleRecordDraft(_ draft: RecordDraft, original: String) {
        let date = draft.date ?? Calendar.current.startOfDay(for: .now)
        let day = cycleStore.day(for: date) ?? CycleDay(date: date)
        if let flow = draft.flow { day.flow = flow }
        for code in draft.symptoms where !day.symptoms.contains(code) {
            day.symptoms.append(code)
        }
        if let mood = draft.mood { day.mood = mood }
        if let note = draft.note, !note.isEmpty { day.note = note }
        Task {
            try? await cycleStore.upsert(day)
            await NotificationService.shared.refreshPeriodReminderIfNeeded(cycleStore: cycleStore)
        }
        let hasCramps = draft.symptoms.contains("cramps")
        let hasFlow = (draft.flow ?? 0) > 0
        let reply = YPersona.RecordFeedback.saved(hasCramps: hasCramps, hasFlow: hasFlow)
        deliver(reply: reply, scenario: hasCramps ? .recordSavedCramps : .recordSaved)
    }

    private func deliver(reply: String, scenario: YVoicePlayer.Scenario?) {
        saveMessage(role: "butler", text: reply)
        if let scenario {
            YVoicePlayer.shared.playScenario(scenario)
        } else if let settings = appState.settings, settings.lanTTSEnabled, !settings.lanTTSBaseURL.isEmpty {
            // 局域网实时 TTS：用主人电脑的 CosyVoice 合成任意文本
            Task {
                await LanTTSService.shared.speak(text: reply, baseURL: settings.lanTTSBaseURL)
            }
        }
    }

    private func saveMessage(role: String, text: String) {
        let message = ButlerMessage(role: role, text: text)
        modelContext.insert(message)
        try? modelContext.save()
    }

    /// 模板兜底回复（无 LLM key 时）
    private func templateReply(_ text: String) -> (reply: String, scenario: YVoicePlayer.Scenario?) {
        ButlerTemplateReply.reply(for: text)
    }
}

/// 聊天气泡（简洁）
private struct MessageBubble: View {
    let message: ButlerMessage

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.role == "butler" {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(YLTheme.primary)
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
                    .background(YLTheme.brandGradient, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            }
        }
    }
}
