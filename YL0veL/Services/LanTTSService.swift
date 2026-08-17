import Foundation
import AVFoundation

/// 局域网实时 TTS：调用主人电脑上的 CosyVoice 服务（OpenAI 兼容 /v1/audio/speech）
/// 桃桃在家时可用；关闭/不可达时静默降级
final class LanTTSService: ObservableObject {

    static let shared = LanTTSService()

    @Published private(set) var lastHealthStatus: Bool?

    private var player: AVAudioPlayer?

    private init() {}

    /// 连通测试
    func healthCheck(baseURL: String) async -> Bool {
        let normalized = normalizeBaseURL(baseURL)
        guard let url = URL(string: normalized + "/health") else {
            lastHealthStatus = false
            return false
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 5
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            let ok = (response as? HTTPURLResponse)?.statusCode == 200
            lastHealthStatus = ok
            return ok
        } catch {
            lastHealthStatus = false
            return false
        }
    }

    /// 合成并播放（返回是否成功）
    @discardableResult
    func speak(text: String, baseURL: String) async -> Bool {
        let normalized = normalizeBaseURL(baseURL)
        guard let url = URL(string: normalized + "/v1/audio/speech") else { return false }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = ["model": "index-tts-2", "input": text]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return false }
            try AVAudioSession.sharedInstance().setCategory(.playback, options: [.duckOthers])
            let audio = try AVAudioPlayer(data: data)
            player = audio
            audio.play()
            return true
        } catch {
            return false
        }
    }

    func stop() {
        player?.stop()
        player = nil
    }

    private func normalizeBaseURL(_ raw: String) -> String {
        var url = raw.trimmingCharacters(in: .whitespaces)
        while url.hasSuffix("/") {
            url.removeLast()
        }
        return url
    }
}
