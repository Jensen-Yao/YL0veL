import Foundation

/// 语音/文本解析的统一输出（规则解析器与 LLM 解析器共用）
struct RecordDraft: Codable, Equatable {
    var date: Date?
    var flow: Int?
    var symptoms: [String]
    var mood: String?
    var note: String?

    var isEmpty: Bool {
        flow == nil && symptoms.isEmpty && mood == nil && (note?.isEmpty ?? true)
    }
}

/// 离线规则解析器：中文关键词/正则（无网可用、确定性；失败时降级到 LLM）
struct RecordParser {

    let today: Date

    init(today: Date = .now) {
        self.today = today
    }

    /// 解析一段口语/文本。返回 nil 表示无法解析出任何有效字段。
    func parse(_ text: String) -> RecordDraft? {
        let normalized = text
            .replacingOccurrences(of: "，", with: ",")
            .replacingOccurrences(of: "。", with: ".")
            .replacingOccurrences(of: "！", with: "!")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return nil }

        var draft = RecordDraft(date: nil, flow: nil, symptoms: [], mood: nil, note: normalized)

        draft.date = parseDate(normalized)
        draft.flow = parseFlow(normalized)
        draft.symptoms = parseSymptoms(normalized)
        draft.mood = parseMood(normalized)

        // 全部失败且无日期 → 返回 nil 让 LLM 接手
        if draft.flow == nil && draft.symptoms.isEmpty && draft.mood == nil && draft.date == nil {
            return nil
        }
        return draft
    }

    // MARK: - 日期归一

    private func parseDate(_ text: String) -> Date? {
        let calendar = Calendar.current
        let day = calendar.startOfDay(for: today)

        if text.contains("大前天") {
            return calendar.date(byAdding: .day, value: -3, to: day)
        }
        if text.contains("前天") {
            return calendar.date(byAdding: .day, value: -2, to: day)
        }
        if text.contains("昨天") {
            return calendar.date(byAdding: .day, value: -1, to: day)
        }
        if text.contains("今天") || text.contains("今早") || text.contains("早上") {
            return day
        }

        // 「上周三/这周三/周三/星期X/周X」（中文按周一起始的周语义）
        let weekdayMap: [String: Int] = [
            "周一": 2, "周二": 3, "周三": 4, "周四": 5, "周五": 6, "周六": 7, "周日": 1,
            "星期一": 2, "星期二": 3, "星期三": 4, "星期四": 5, "星期五": 6, "星期六": 7, "星期日": 1,
            "礼拜一": 2, "礼拜二": 3, "礼拜三": 4, "礼拜四": 5, "礼拜五": 6, "礼拜六": 7, "礼拜天": 1,
        ]
        for (keyword, targetWeekday) in weekdayMap {
            guard text.contains(keyword) else { continue }
            // 转换为 ISO 周（周一=1 ... 周日=7），中文「本周」按周一起始
            let currentISO = ((calendar.component(.weekday, from: today) + 5) % 7) + 1
            let targetISO = ((targetWeekday + 5) % 7) + 1
            var delta = targetISO - currentISO
            if text.contains("上周") || text.contains("上星期") || text.contains("上个") {
                delta -= 7
            } else if text.contains("下周") || text.contains("下星期") {
                delta += 7
            } else if delta > 0 && !text.contains("这周") && !text.contains("本周") {
                // 无修饰的「周X」默认理解为最近的过去（健康记录回顾语境）
                delta -= 7
            }
            return calendar.date(byAdding: .day, value: delta, to: day)
        }

        // 「N天前」
        if let range = text.range(of: #"(\d+)\s*天前"#, options: .regularExpression) {
            let digits = text[range].filter(\.isNumber)
            let number = Int(String(digits)) ?? 0
            return calendar.date(byAdding: .day, value: -number, to: day)
        }

        // 「M月D日 / M月D号」
        let patterns = [#"(\d{1,2})月(\d{1,2})[日号]"#]
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
               let monthRange = Range(match.range(at: 1), in: text),
               let dayRange = Range(match.range(at: 2), in: text),
               let month = Int(text[monthRange]), let dayOfMonth = Int(text[dayRange]),
               month >= 1, month <= 12, dayOfMonth >= 1, dayOfMonth <= 31 {
                var components = calendar.dateComponents([.year, .month, .day], from: today)
                components.month = month
                components.day = dayOfMonth
                if let parsed = calendar.date(from: components), parsed > today {
                    components.year = (calendar.component(.year, from: today)) - 1
                }
                return calendar.date(from: components)
            }
        }

        return nil
    }

    // MARK: - 流量

    private func parseFlow(_ text: String) -> Int? {
        if text.contains("量多") || text.contains("量大") || text.contains("量很大") || text.contains("很多") || text.contains("挺多") {
            return FlowLevel.heavy.rawValue
        }
        if text.contains("量少") || text.contains("一点点") || text.contains("不多") || text.contains("量不多") {
            return FlowLevel.light.rawValue
        }
        if text.contains("量中等") || text.contains("一般") {
            return FlowLevel.medium.rawValue
        }
        // 「来了/来的/大姨妈/例假/月经」默认中等流量
        if text.contains("来了") || text.contains("来的") || text.contains("大姨妈") || text.contains("例假") || text.contains("月经") || text.contains("姨妈") {
            return FlowLevel.medium.rawValue
        }
        return nil
    }

    // MARK: - 症状词表

    private let symptomKeywords: [(String, String)] = [
        ("痛经", "cramps"), ("肚子疼", "cramps"), ("肚子痛", "cramps"), ("肚子好疼", "cramps"), ("腹痛", "cramps"), ("姨妈痛", "cramps"),
        ("排卵痛", "ovulationPain"),
        ("头痛", "headache"), ("头疼", "headache"),
        ("腰酸", "backache"), ("腰痛", "backache"), ("背痛", "backache"), ("腰疼", "backache"), ("腰好痛", "backache"),
        ("恶心", "nausea"), ("想吐", "nausea"),
        ("胸胀", "tenderBreasts"), ("乳房胀", "tenderBreasts"), ("胸部胀", "tenderBreasts"),
        ("偏头痛", "migraine"),
        ("疲劳", "fatigue"), ("好累", "fatigue"), ("很累", "fatigue"), ("没精神", "fatigue"),
        ("腹胀", "bloating"), ("胀气", "bloating"), ("肚子胀", "bloating"),
        ("头晕", "dizziness"),
        ("长痘", "acne"), ("爆痘", "acne"), ("痘痘", "acne"),
        ("腹泻", "diarrhea"), ("拉肚子", "diarrhea"),
        ("失眠", "insomnia"), ("睡不着", "insomnia"),
        ("食欲", "appetiteChange"), ("胃口", "appetiteChange"),
    ]

    private func parseSymptoms(_ text: String) -> [String] {
        var codes: [String] = []
        for (keyword, code) in symptomKeywords where text.contains(keyword) {
            if !codes.contains(code) {
                codes.append(code)
            }
        }
        return codes
    }

    // MARK: - 情绪

    private let moodKeywords: [(String, String)] = [
        ("开心", "happy"), ("高兴", "happy"),
        ("平静", "calm"),
        ("烦躁", "irritated"), ("易怒", "irritated"), ("烦死", "irritated"), ("脾气", "irritated"),
        ("难过", "sad"), ("伤心", "sad"), ("想哭", "sad"),
        ("焦虑", "anxious"), ("紧张", "anxious"),
        ("疲惫", "tired"), ("累", "tired"),
        ("活力", "energetic"), ("精神好", "energetic"), ("状态好", "energetic"),
    ]

    private func parseMood(_ text: String) -> String? {
        for (keyword, code) in moodKeywords.reversed() where text.contains(keyword) {
            return code
        }
        return nil
    }
}
