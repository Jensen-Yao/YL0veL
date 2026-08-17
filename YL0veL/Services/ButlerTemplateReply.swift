import Foundation

/// 管家模板回复（无 LLM 时兜底；可单测）
enum ButlerTemplateReply {

    /// 根据输入返回模板回复与对应的语音场景
    static func reply(for text: String) -> (reply: String, scenario: YVoicePlayer.Scenario?) {
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
