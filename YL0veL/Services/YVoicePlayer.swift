import Foundation
import AVFoundation

/// 主人语音播放器：播放打包进 App 的管家话术语音包（离线、隐私）
/// 语音包位于 Resources/YVoice/<场景名>.mp3；未启用或文件缺失时静默回退（不报错）
final class YVoicePlayer: NSObject, ObservableObject, AVAudioPlayerDelegate {

    static let shared = YVoicePlayer()

    /// 全局语音开关（由 AppSettings.voiceEnabled 同步）
    static var isEnabled = false

    private var player: AVAudioPlayer?
    private var sequence: [Scenario] = []

    private override init() {
        super.init()
    }

    /// 管家话术场景（rawValue = 语音包文件名，不含扩展名）
    enum Scenario: String, CaseIterable {
        // 引导
        case onboardingGreeting = "onboarding_greeting"
        case onboardingWelcome = "onboarding_welcome"
        case onboardingFinish = "onboarding_finish"
        // 经期提醒
        case periodComing3 = "period_coming_3"
        case periodComing2 = "period_coming_2"
        case periodComing1 = "period_coming_1"
        case periodToday = "period_today"
        case periodEnded = "period_ended"
        case prepareList = "prepare_list"
        // 排卵
        case ovulationWindow = "ovulation_window"
        case ovulationTrying = "ovulation_trying"
        case ovulationAvoiding = "ovulation_avoiding"
        // 记录反馈
        case recordSaved = "record_saved"
        case recordSavedCramps = "record_saved_cramps"
        case recordTemperature = "record_temperature"
        case recordWater = "record_water"
        // 报告
        case reportReady = "report_ready"
        case reportPraise = "report_praise"
        case reportComfort = "report_comfort"
        case reportCrampsCare = "report_cramps_care"
        // 日常问候
        case greetMorning = "greet_morning"
        case greetNight = "greet_night"
        case drinkWater = "drink_water"
        case moodCare = "mood_care"
        case hug = "hug"
        // 对话兜底
        case chatHere = "chat_here"
        case chatOk = "chat_ok"
        case chatPraise = "chat_praise"
    }

    /// 播放场景语音；语音未启用或音频缺失时静默
    func playScenario(_ scenario: Scenario) {
        play(named: scenario.rawValue)
    }

    /// 按文件名播放（不含扩展名）
    func play(named name: String) {
        guard YVoicePlayer.isEnabled else { return }
        guard let url = Bundle.main.url(forResource: name, withExtension: "mp3", subdirectory: "YVoice") else { return }
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, options: [.duckOthers])
            player = try AVAudioPlayer(contentsOf: url)
            player?.play()
        } catch {
            // 语音播放失败静默降级（不影响文字功能）
        }
    }

    func stop() {
        sequence = []
        player?.stop()
        player = nil
    }

    /// 顺序播放一组场景（报告朗读等）；缺失片段自动跳过
    func playSequence(_ scenarios: [Scenario]) {
        guard YVoicePlayer.isEnabled else { return }
        stop()
        sequence = scenarios
        playNext()
    }

    private func playNext() {
        guard !sequence.isEmpty else { return }
        let next = sequence.removeFirst()
        guard let url = Bundle.main.url(forResource: next.rawValue, withExtension: "mp3", subdirectory: "YVoice") else {
            playNext()
            return
        }
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, options: [.duckOthers])
            player = try AVAudioPlayer(contentsOf: url)
            player?.delegate = self
            player?.play()
        } catch {
            playNext()
        }
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.playNext()
        }
    }
}
