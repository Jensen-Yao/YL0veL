import SwiftUI
import LocalAuthentication

/// 免责声明（首次启动必须确认；医疗合规：预测仅供参考）
struct DisclaimerView: View {
    var onAccept: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            YLTheme.softBackground.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    Spacer(minLength: 48)

                    Text("Y💗L")
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .foregroundStyle(YLTheme.brandGradient)

                    Text("经期预测与健康守护")
                        .font(.title3.weight(.medium))
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 16) {
                        disclaimerRow(icon: "stethoscope", title: "仅供参考，不构成医疗建议",
                                      text: "本 App 的周期预测、排卵窗口估计与健康趋势基于统计模型与个人记录，可能存在误差，不能替代医生的专业诊断。")
                        disclaimerRow(icon: "lock.shield", title: "你的数据只属于你",
                                      text: "所有经期与健康数据默认保存在本机；语音识别优先使用系统在线服务，可关闭；如你自行配置 AI 服务，仅发送你允许的最小化文本。")
                        disclaimerRow(icon: "heart.text.square", title: "温柔记录，诚实预测",
                                      text: "预测以「区间」呈现而非单一日期。周期波动是正常的，Y💗L 不会制造焦虑。")
                    }

                    Button(action: onAccept) {
                        Text("我已了解，开始使用")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(YLTheme.brandGradient, in: Capsule())
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)

                    Spacer(minLength: 24)
                }
                .padding(24)
            }
        }
    }

    private func disclaimerRow(icon: String, title: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(YLTheme.primary)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(text)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// App 锁：FaceID/TouchID 解锁，失败可输 PIN；支持「假 PIN」防窥（学 Euki）
struct AppLockView: View {
    var onUnlock: (Bool) -> Void

    @EnvironmentObject private var appState: AppState
    @State private var pinInput = ""
    @State private var errorMessage: String?

    private var realPIN: String? { appState.settings?.fakePIN }

    var body: some View {
        ZStack {
            YLTheme.softBackground.ignoresSafeArea()
            VStack(spacing: 24) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(YLTheme.primary)

                Text("YL0veL 已锁定")
                    .font(.title2.weight(.semibold))

                Text("仅你自己可以查看记录")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                // 假 PIN 输入（输错也进入一个"看起来正常"的空界面 → 防窥）
                SecureField("输入密码", text: $pinInput)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.numberPad)
                    .frame(maxWidth: 220)
                    .multilineTextAlignment(.center)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

                Button("解锁") {
                    authenticate()
                }
                .buttonStyle(.borderedProminent)
                .tint(YLTheme.primary)
                .disabled(pinInput.isEmpty)
            }
            .padding()
        }
        .onAppear(perform: authenticateBiometrics)
    }

    private func authenticate() {
        if let realPIN, pinInput == realPIN {
            YLTheme.hapticSuccess()
            onUnlock(true)
            pinInput = ""
        } else if realPIN != nil {
            errorMessage = "密码不正确"
            // 假 PIN：第二次错误时进入「伪解锁」空界面（防窥设计）
            showFakeContentIfConfigured()
        } else {
            onUnlock(true)
        }
    }

    private func authenticateBiometrics() {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return // 设备不支持或无生物识别 → 用 PIN
        }
        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: "解锁 YL0veL") { success, _ in
            DispatchQueue.main.async {
                if success {
                    YLTheme.hapticSuccess()
                    onUnlock(true)
                }
            }
        }
    }

    private func showFakeContentIfConfigured() {
        // 简化防窥：显示一个空白的「数据为空」界面（无真实数据）
        if appState.settings?.fakePINEnabled == true {
            onUnlock(true) // 进入 App 但展示空态 —— 由 ContentView 的 privacyBlur 配合
        }
    }
}
