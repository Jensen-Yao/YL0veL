import Foundation
import YL0veLPredictionKit

/// 管家 Y 人格文案引擎：全 App 话术统一来源
/// 语气规范：称呼使用者「桃桃」、自称「管家 Y」；亲昵、温柔、守护感；不制造焦虑、不医疗恐吓
enum YPersona {

    static let userNickname = "桃桃"
    static let assistantName = "管家 Y"

    static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "M月d日"
        return f
    }()

    // MARK: - 通知 / Notifications

    enum Notification {
        /// 经期将至（提前 N 天）
        static func periodComing(advanceDays: Int, windowStart: Date, windowEnd: Date) -> (title: String, body: String) {
            let range = "\(YPersona.dayFormatter.string(from: windowStart)) ~ \(YPersona.dayFormatter.string(from: windowEnd))"
            return (
                "\(YPersona.userNickname)，准备接驾啦 🌸",
                "经期预计还有 \(advanceDays) 天到访（\(range)）。管家 Y 已经把准备清单列好啦，记得看一眼哦 💗"
            )
        }

        /// 经期预计今天开始
        static func periodToday() -> (title: String, body: String) {
            return (
                "\(YPersona.userNickname)，今天辛苦啦 🫶",
                "经期预计今天到访。管家 Y 在呢，热敷、红糖水都备好，不舒服就多休息 💗"
            )
        }

        /// 报告生成
        static func reportReady(reportTitle: String) -> (title: String, body: String) {
            return (
                "\(YPersona.userNickname)的周期报告来啦 📋",
                "\(reportTitle) —— 管家 Y 整理好了，点开看看这个周期的身体变化吧"
            )
        }

        /// 晨间体温提醒
        static func morningTemperature() -> (title: String, body: String) {
            return (
                "\(YPersona.userNickname)，晨间体温时间 🌡️",
                "醒来记得量一下基础体温哦，管家 Y 帮你记着"
            )
        }

        /// 准备清单逐项提醒
        static func prepareChecklist(item: String, daysLeft: Int) -> (title: String, body: String) {
            return (
                "\(YPersona.userNickname)，清单确认时间 🎒",
                "「\(item)」记得放进包包哦，还有 \(daysLeft) 天经期就要到啦"
            )
        }

        /// 排卵窗口（按模式）
        static func ovulationWindow(mode: CycleMode) -> (title: String, body: String) {
            switch mode {
            case .tryingToConceive:
                return (
                    "\(YPersona.userNickname)，好时机来啦 💕",
                    "这几天是排卵窗口期，想要宝宝的话，管家 Y 帮你加油哦"
                )
            case .avoidingPregnancy:
                return (
                    "\(YPersona.userNickname)，防护提醒 🛡️",
                    "排卵窗口期到啦，这几天记得做好防护哦，管家 Y 提醒过你啦"
                )
            default:
                return (
                    "\(YPersona.userNickname)，排卵窗口期 ✨",
                    "这几天是排卵窗口期，身体状态会有小变化，管家 Y 都看在眼里"
                )
            }
        }
    }

    // MARK: - 报告关怀 / Report Care

    enum Report {
        /// 周期报告关怀文案（模板库；配 LLM 时可生成更个性化版本）
        static func care(score: Double, crampDays: Int, headacheDays: Int) -> String {
            if score >= 85 && crampDays == 0 {
                return "\(YPersona.userNickname)这个周期非常规律，身体状态很棒！管家 Y 为你开心，继续保持规律作息、多喝温水哦 🌸"
            }
            if crampDays > 0 && headacheDays > 0 {
                return "这个周期辛苦了，痛经 \(crampDays) 天、头痛 \(headacheDays) 天，管家 Y 都记下了。下次经期前一周，我会提前提醒你热敷、早睡、少喝冰的，让身体舒服一点 💗"
            }
            if crampDays > 0 {
                return "这个周期有 \(crampDays) 天痛经，抱抱 \(YPersona.userNickname)。经期前少喝冰饮和咖啡会舒服一些，管家 Y 会提前提醒你的 🫶"
            }
            if score < 55 {
                return "周期最近有点波动，\(YPersona.userNickname)不用太担心，压力、作息都会影响它。管家 Y 会一直陪着你记录，慢慢就懂你啦 💗"
            }
            return "记录得很完整，真棒！管家 Y 会继续陪着你，一起把身体照顾得妥妥的 ✨"
        }
    }

    // MARK: - 引导 / Onboarding

    enum Onboarding {
        static let page1Title = "你好呀，\(YPersona.userNickname) 🌸"
        static let page1Body = "我是管家 Y，主人派我来守护你。\n以后你的经期、心情、健康，都由我贴心照看。"

        static let page2Title = "确认一下称呼"
        static let page2Body = "主人说，要叫你「\(YPersona.userNickname)」。对吗？不喜欢的话可以改一个。"

        static let page3Title = "三个小秘密"
        static let page3Body = "为了马上开始守护，告诉我：上次经期是哪天？平均周期多久？经期一般几天？"

        static let page4Title = "主人的声音 💌"
        static let page4Body = "主人把他的声音留给了我。要不要让我用主人的声音陪着你？"

        static let tryVoiceButton = "试听主人的声音"
        static let enableVoiceButton = "开启主人语音"
        static let skipVoiceButton = "暂时不用"
        static let finishButton = "开始守护"
    }

    // MARK: - 对话兜底 / Chat Fallbacks（无 LLM 时）

    enum Chat {
        static let greeting = "\(YPersona.userNickname)，我在呢 💗 今天感觉怎么样？"
        static let morning = "早呀 \(YPersona.userNickname)，新的一天也要元气满满哦 🌸"
        static let night = "晚安 \(YPersona.userNickname)，早点休息，管家 Y 守着你 🌙"
        static let hug = "抱抱，管家 Y 在呢。不舒服就跟我说 🫶"
        static let recordHint = "想记录的话直接告诉我，比如「今天来了，肚子有点疼」"
        static let reportHint = "最新周期报告可以点右上角的「报告」查看哦，管家 Y 都整理好啦"
        static let preparingHint = "经期快到了，管家 Y 已经把准备清单列好啦，去看看吧 🎒"
        static let praise = "\(YPersona.userNickname)真棒，又认真记录了一天 ✨"
        static let unknown = "管家 Y 有点没听懂，不过没关系的，桃桃说什么我都愿意听 💗"
    }

    // MARK: - 记录反馈（保存后即时话术）

    enum RecordFeedback {
        static func saved(hasCramps: Bool, hasFlow: Bool) -> String {
            if hasCramps {
                return "抱抱 \(YPersona.userNickname)，管家 Y 记下啦。热敷会舒服一点，主人说红糖水已经备好啦 💗"
            }
            if hasFlow {
                return "记下啦，\(YPersona.userNickname)。经期这几天我都在，多喝温水、早点休息哦 🌸"
            }
            return "收到啦 ✨ 管家 Y 都记好了"
        }
    }

    // MARK: - 空态与提示 / Empty States

    enum Empty {
        static let noPrediction = "\(YPersona.userNickname)，再记 2~3 个周期，管家 Y 就能开始预测啦 🌱"
        static let noReport = "还没有周期报告哦。每次经期结束后，管家 Y 会为你整理一份专属报告 💗"
        static let noTemperature = "还没读到手腕温度。你的手表若支持，佩戴入睡几晚后管家 Y 就能看到啦；不支持也没关系，其他守护照常进行 🌸"
        static let noHealthData = "授权后管家 Y 会自动读取这些数据哦"
    }

    // MARK: - 周期相位 / Cycle Phases

    enum Phase {
        static func name(_ phase: CyclePhase) -> String {
            switch phase {
            case .menstrual: return "经期"
            case .follicular: return "卵泡期"
            case .ovulation: return "排卵期"
            case .luteal: return "黄体期"
            }
        }

        static func emoji(_ phase: CyclePhase) -> String {
            switch phase {
            case .menstrual: return "🩸"
            case .follicular: return "🌱"
            case .ovulation: return "✨"
            case .luteal: return "🌙"
            }
        }

        static func description(_ phase: CyclePhase) -> String {
            switch phase {
            case .menstrual:
                return "经期这几天，身体在认真休整。注意保暖、少碰冰的，管家 Y 陪着你 🫶"
            case .follicular:
                return "卵泡期是状态回升的几天，精神会越来越好，适合运动与安排重要的事 🌱"
            case .ovulation:
                return "排卵期到了，身体状态最佳，魅力值也拉满。这几天白带可能增多，是正常的哦 ✨"
            case .luteal:
                return "黄体期到了，情绪可能有点小波动、胸胀易累，都是正常的。早点休息、吃点暖的 🌙"
            }
        }

        static func advice(_ phase: CyclePhase) -> String {
            switch phase {
            case .menstrual:
                return "今天适合：热敷小腹、早睡、喝点红糖姜茶。剧烈运动先放一放哦 💗"
            case .follicular:
                return "今天适合：运动健身、处理重要的事。精力充沛就多爱自己一点 🌸"
            case .ovulation:
                return "今天适合：保持好心情、注意补水。想要记录的话，白带变化值得记一笔 ✨"
            case .luteal:
                return "今天适合：温和运动、早睡、吃点含镁的食物（坚果/香蕉）。情绪波动时抱抱自己 🌙"
            }
        }
    }

    // MARK: - 痛经预警 / Health Alerts

    enum Alert {
        static func crampsWorsening(cycles: Int) -> String {
            "\(YPersona.userNickname)，最近 \(cycles) 个周期的痛经天数在增加。管家 Y 有点心疼，有空的话记得看看医生，让我更放心 💗"
        }

        static func cycleIrregular() -> String {
            "周期最近有点小波动，管家 Y 会继续观察。别担心，很多因素都会影响它，我们一起慢慢看 🌸"
        }
    }
}
