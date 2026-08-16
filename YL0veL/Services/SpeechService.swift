import Foundation
import Speech
import AVFoundation

/// 语音识别服务：SFSpeechRecognizer 中文（在线优先；离线可用时自动使用）
final class SpeechService: ObservableObject {

    enum SpeechError: Error, LocalizedError {
        case notAuthorized
        case notAvailable
        case cancelled

        var errorDescription: String? {
            switch self {
            case .notAuthorized: return "未获得语音识别权限，请在系统设置中开启"
            case .notAvailable: return "当前设备不支持语音识别"
            case .cancelled: return "已取消"
            }
        }
    }

    @Published private(set) var isRecording = false
    @Published private(set) var liveTranscript = ""

    private let recognizer: SFSpeechRecognizer?
    private var audioEngine: AVAudioEngine?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    init(locale: Locale = Locale(identifier: "zh-CN")) {
        recognizer = SFSpeechRecognizer(locale: locale)
    }

    var isAvailable: Bool { recognizer?.isAvailable ?? false }
    var supportsOnDeviceRecognition: Bool { recognizer?.supportsOnDeviceRecognition ?? false }

    func requestAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    /// 开始识别；结果经 `onResult` 回调（可能多次，取最终完整文本）
    func start(onResult: @escaping (String) -> Void, onError: @escaping (Error) -> Void) throws {
        guard let recognizer, recognizer.isAvailable else { throw SpeechError.notAvailable }

        stop()

        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        let engine = AVAudioEngine()
        audioEngine = engine
        let recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        recognitionRequest.shouldReportPartialResults = true
        if supportsOnDeviceRecognition {
            recognitionRequest.requiresOnDeviceRecognition = false // 在线优先，Apple 自动降级
        }
        request = recognitionRequest

        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            recognitionRequest.append(buffer)
        }

        engine.prepare()
        try engine.start()

        isRecording = true
        liveTranscript = ""

        task = recognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            DispatchQueue.main.async {
                guard let self else { return }
                if let result {
                    self.liveTranscript = result.bestTranscription.formattedString
                }
                if let error {
                    self.stop()
                    onError(error)
                    return
                }
                if result?.isFinal == true {
                    let text = result?.bestTranscription.formattedString ?? ""
                    self.stop()
                    onResult(text)
                }
            }
        }
    }

    func stop() {
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        request?.endAudio()
        request = nil
        task?.cancel()
        task = nil
        isRecording = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
