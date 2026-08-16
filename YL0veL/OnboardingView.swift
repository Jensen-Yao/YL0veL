import SwiftUI
import SwiftData

/// 首次启动引导：管家 Y 自我介绍 → 昵称确认 → 周期信息收集 → 主人语音开关
struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appState: AppState

    @State private var page = 0
    @State private var nickname = "桃桃"
    @State private var lastPeriodDate = Calendar.current.date(byAdding: .day, value: -14, to: .now)!
    @State private var averageCycleLength = 28
    @State private var periodLength = 5
    @State private var voiceEnabled = false
    @State private var voicePlaying = false

    var body: some View {
        ZStack {
            YLTheme.softBackground.ignoresSafeArea()

            VStack {
                // 进度点
                HStack(spacing: 8) {
                    ForEach(0..<4, id: \.self) { index in
                        Capsule()
                            .fill(index == page ? YLTheme.primary : Color.gray.opacity(0.2))
                            .frame(width: index == page ? 24 : 8, height: 8)
                    }
                }
                .padding(.top, 40)
                .animation(.spring(duration: 0.3, bounce: 0), value: page)

                TabView(selection: $page) {
                    introPage.tag(0)
                    nicknamePage.tag(1)
                    cycleInfoPage.tag(2)
                    voicePage.tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.spring(duration: 0.35, bounce: 0), value: page)

                // 底部按钮
                Button {
                    advance()
                } label: {
                    Text(buttonTitle)
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(YLTheme.brandGradient, in: Capsule())
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
    }

    private var buttonTitle: String {
        page == 3 ? "开始守护" : "继续"
    }

    private func advance() {
        YLTheme.haptic(.light)
        if page < 3 {
            withAnimation { page += 1 }
        } else {
            finish()
        }
    }

    private func finish() {
        guard let settings = appState.settings else { return }
        settings.hasCompletedOnboarding = true
        settings.nickname = nickname.isEmpty ? "桃桃" : nickname
        settings.voiceEnabled = voiceEnabled
        settings.updatedAt = .now
        try? modelContext.save()

        // 写入引导收集的周期信息（快速起步：构造最近 4 个历史周期）
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: lastPeriodDate)
        for offset in [0, -averageCycleLength, -2 * averageCycleLength, -3 * averageCycleLength] {
            guard let cycleStart = calendar.date(byAdding: .day, value: offset, to: start) else { continue }
            if cycleStart > .now { continue }
            for dayIndex in 0..<periodLength {
                guard let date = calendar.date(byAdding: .day, value: dayIndex, to: cycleStart) else { continue }
                if date > .now { continue }
                let day = CycleDay(date: date, flow: dayIndex <= 1 ? FlowLevel.medium.rawValue : FlowLevel.light.rawValue)
                modelContext.insert(day)
            }
        }
        try? modelContext.save()
        YLTheme.hapticSuccess()
        appState.showDisclaimer = false
    }

    // MARK: - 第 1 页：自我介绍

    private var introPage: some View {
        VStack(spacing: 20) {
            Spacer()
            Text("🤵‍♂️")
                .font(.system(size: 72))
            Text(YPersona.Onboarding.page1Title)
                .font(.title.weight(.bold))
                .multilineTextAlignment(.center)
            Text(YPersona.Onboarding.page1Body)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
            Spacer()
        }
    }

    // MARK: - 第 2 页：昵称确认

    private var nicknamePage: some View {
        VStack(spacing: 20) {
            Spacer()
            Text("💌")
                .font(.system(size: 56))
            Text(YPersona.Onboarding.page2Title)
                .font(.title2.weight(.bold))
            Text(YPersona.Onboarding.page2Body)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            TextField("你的昵称", text: $nickname)
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 240)
                .font(.title3.weight(.semibold))
            Spacer()
            Spacer()
        }
    }

    // MARK: - 第 3 页：周期信息收集

    private var cycleInfoPage: some View {
        VStack(spacing: 20) {
            Spacer()
            Text("🔮")
                .font(.system(size: 56))
            Text(YPersona.Onboarding.page3Title)
                .font(.title2.weight(.bold))
            Text(YPersona.Onboarding.page3Body)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            VStack(spacing: 0) {
                DatePicker("上次经期开始", selection: $lastPeriodDate, in: ...Date.now, displayedComponents: .date)
                    .padding()
                Divider()
                Stepper("平均周期 \(averageCycleLength) 天", value: $averageCycleLength, in: 20...45)
                    .padding()
                Divider()
                Stepper("经期持续 \(periodLength) 天", value: $periodLength, in: 2...10)
                    .padding()
            }
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .padding(.horizontal, 24)

            Spacer()
            Spacer()
        }
    }

    // MARK: - 第 4 页：主人语音

    private var voicePage: some View {
        VStack(spacing: 20) {
            Spacer()
            Text("🎙️")
                .font(.system(size: 56))
            Text(YPersona.Onboarding.page4Title)
                .font(.title2.weight(.bold))
            Text(YPersona.Onboarding.page4Body)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            // 试听按钮（语音包生成后生效；无语音包时静默）
            Button {
                YVoicePlayer.shared.playScenario(.onboardingGreeting)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "speaker.wave.2.fill")
                    Text(YPersona.Onboarding.tryVoiceButton)
                }
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(YLTheme.primary.opacity(0.12), in: Capsule())
                .foregroundStyle(YLTheme.primary)
            }
            .buttonStyle(.plain)

            Toggle(YPersona.Onboarding.enableVoiceButton, isOn: $voiceEnabled)
                .toggleStyle(.switch)
                .padding(.horizontal, 60)

            Spacer()
            Spacer()
        }
    }
}
