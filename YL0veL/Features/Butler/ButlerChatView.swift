import SwiftUI
import SwiftData

/// 管家 Y 对话 Tab：桃桃与管家聊天（模板兜底 + 可选 LLM + 记录意图识别 + 主人语音回复）
@MainActor
struct ButlerChatView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var cycleStore: CycleStore

    @Query(sort: \ButlerMessage.timestamp) private var messages: [ButlerMessage]

    @State private var inputText = ""
    @State private var isThinking = false
    @StateObject private var speech = SpeechService()

    private var llmConfig: LLMConfig? {
        let descriptor = FetchDescriptor<LLMConfig>()
        return (try? modelContext.fetch(descriptor).first).flatMap { $0.enabled ? $0 : nil }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if messages.isEmpty {
                    welcomeView
                } else {
                    messageList
                }

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
        }
    }

    // MARK: - 欢迎

    private var welcomeView: some View {
        VStack(spacing: 16) {
            Spacer()
            Text("🤵‍♂️")
                .font(.system(size: 64))
            Text("桃桃，我在呢 💗")
                .font(.title2.weight(.bold))
            Text("想记录就直接说，比如「今天来了，肚子有点疼」；\n想聊天也随时可以，管家 Y 都在。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
            Spacer()
        }
    }

    // MARK: - 消息列表

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(messages) { message in
                        MessageBubble(message: message)
                            .id(message.id)
                    }
                    if isThinking {
                        HStack {
                            Text("🤵‍♂️ 管家 Y 正在想…")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
                            Spacer()
                        }
                    }
                }
                .padding()
            }
            .onChange(of: messages.count) { _, _ in
                if let last = messages.last {
                    withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
        }
    }

    // MARK: - 输入栏

    private var inputBar: some View {
        HStack(spacing: 10) {
            // 语音输入
            Button {
                toggleVoiceInput()
            } label: {
                Image(systemName: speech.isRecording ? "stop.circle.fill" : "mic.circle")
                    .font(.system(size: 26))
                    .foregroundStyle(speech.isRecording ? .red : YLTheme.primary)
            }
            .buttonStyle(.plain)

            TextField("跟管家 Y 说点什么…", text: $inputText, axis: .vertical)
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

        // 1) 记录意图：离线规则解析优先（与语音记录一致）
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
                    deliver(reply: templateReply(text).reply, scenario: templateReply(text).scenario)
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
        }
    }

    private func saveMessage(role: String, text: String) {
        let message = ButlerMessage(role: role, text: text)
        modelContext.insert(message)
        try? modelContext.save()
    }

    /// 模板兜底回复（无 LLM key 时）
    private func templateReply(_ text: String) -> (reply: String, scenario: YVoicePlayer.Scenario?) {
        if text.contains("早") {
            return (YPersona.Chat.morning, .greetMorning)
        }
        if text.contains("晚安") || text.contains("睡了") {
            return (YPersona.Chat.night, .greetNight)
        }
        if text.contains("报告") {
            return (YPersona.Chat.reportHint, .reportReady)
        }
        if text.contains("清单") || text.contains("准备") {
            return (YPersona.Chat.preparingHint, .prepareList)
        }
        if text.contains("抱") || text.contains("难过") || text.contains("疼") || text.contains("痛") || text.contains("哭") {
            return (YPersona.Chat.hug, .hug)
        }
        if text.contains("记录") || text.contains("记") {
            return (YPersona.Chat.recordHint, nil)
        }
        if text.contains("谢谢") || text.contains("棒") {
            return (YPersona.Chat.praise, .chatPraise)
        }
        return (YPersona.Chat.greeting, .chatHere)
    }
}

/// 聊天气泡
private struct MessageBubble: View {
    let message: ButlerMessage

    var body: some View {
        HStack {
            if message.role == "butler" {
                Text("🤵‍♂️")
                    .font(.system(size: 26))
                Text(message.text)
                    .font(.subheadline)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                Spacer(minLength: 40)
            } else {
                Spacer(minLength: 40)
                Text(message.text)
                    .font(.subheadline)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .foregroundStyle(.white)
                    .background(YLTheme.brandGradient, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
    }
}
