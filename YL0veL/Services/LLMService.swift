import Foundation

/// LLM 服务：OpenAI 兼容 chat completions（DeepSeek/通义/自定义 baseURL）
/// 用途：①语音文本结构化解析（JSON Schema）②周期报告关怀文案 ③连接测试
/// 隐私：默认仅发送当前句子文本；`includeCycleContext` 显式开启后才附带周期上下文
struct LLMService {

    struct CycleContext {
        let cycleDayNumber: Int
        let averageCycleLength: Int
        let lastPeriodStart: Date?
    }

    enum LLMError: Error, LocalizedError {
        case missingKey
        case invalidURL
        case badResponse
        case apiError(message: String)

        var errorDescription: String? {
            switch self {
            case .missingKey: return "未配置 API Key"
            case .invalidURL: return "API 地址无效"
            case .badResponse: return "响应格式异常"
            case .apiError(let message): return message
            }
        }
    }

    private struct ChatMessage: Codable {
        let role: String
        let content: String
    }

    private struct ChatRequest: Codable {
        let model: String
        let messages: [ChatMessage]
        let temperature: Double
        let responseFormat: ResponseFormat?

        enum CodingKeys: String, CodingKey {
            case model, messages, temperature
            case responseFormat = "response_format"
        }

        struct ResponseFormat: Codable {
            let type: String
        }
    }

    private struct ChatResponse: Codable {
        struct Choice: Codable {
            struct Message: Codable {
                let content: String?
            }
            let message: Message
        }
        struct UsageError: Codable {
            let message: String?
        }
        let choices: [Choice]?
        let error: UsageError?
    }

    // MARK: - 结构化解析

    /// 把口语文本解析为记录草稿。规则引擎失败时才调用。
    static func extractRecordDraft(
        from text: String,
        today: Date,
        config: LLMConfig,
        apiKey: String,
        cycleContext: CycleContext?
    ) async throws -> RecordDraft {
        let schema = """
        {
          "type": "object",
          "properties": {
            "date": {"type": "string", "description": "记录的日期 YYYY-MM-DD；根据今天日期把相对日期（今天/昨天/前天/上周三）换算成绝对日期"},
            "flow": {"type": "integer", "enum": [0,1,2,3], "description": "经血量：0=未提到或无,1=少量,2=中等,3=大量"},
            "symptoms": {"type": "array", "items": {"type": "string", "enum": ["cramps","ovulationPain","headache","backache","nausea","tenderBreasts","migraine","fatigue","bloating","dizziness","acne","diarrhea","insomnia","appetiteChange"]}},
            "mood": {"type": ["string","null"], "enum": ["happy","calm","irritated","sad","anxious","tired","energetic",null]},
            "note": {"type": "string", "description": "用户原话的简短整理备注，可为空字符串"}
          },
          "required": ["date","flow","symptoms","mood","note"]
        }
        """

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        var systemPrompt = """
        你是女性经期健康记录的解析助手。从用户的中文口语描述中提取结构化数据，严格按 JSON Schema 输出 JSON。
        今天日期：\(dateFormatter.string(from: today))。
        规则：flow 仅在用户明确表示来月经时大于 0；「没来/还没来」时 flow=0 且不写症状中的痛经。
        """
        if let context = cycleContext {
            systemPrompt += """
            用户当前是周期第 \(context.cycleDayNumber) 天，平均周期 \(context.averageCycleLength) 天。
            """
        }

        let messages = [
            ChatMessage(role: "system", content: systemPrompt),
            ChatMessage(role: "user", content: "请解析：\(text)\n请只输出符合 Schema 的 JSON 对象：\n\(schema)"),
        ]

        let content = try await chat(messages: messages, config: config, apiKey: apiKey, jsonMode: true)
        // 清理可能的 markdown 代码围栏（json mode 通常纯 JSON，做健壮性兜底）
        let cleaned = content
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = cleaned.data(using: .utf8),
              let json = try? JSONDecoder().decode(RawDraftJSON.self, from: data) else {
            throw LLMError.badResponse
        }

        let parsedDate = dateFormatter.date(from: json.date)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return RecordDraft(
            date: parsedDate,
            flow: json.flow,
            symptoms: json.symptoms ?? [],
            mood: json.mood,
            note: (json.note?.isEmpty ?? true) ? nil : json.note
        )
    }

    private struct RawDraftJSON: Codable {
        let date: String
        let flow: Int?
        let symptoms: [String]?
        let mood: String?
        let note: String?
    }

    // MARK: - 关怀文案

    static func generateCareMessage(
        reportFacts: String,
        config: LLMConfig,
        apiKey: String
    ) async throws -> String {
        let systemPrompt = """
        你是「YL0veL」经期健康守护应用的关怀助手。根据给定的周期报告事实，写一段 2~3 句的温柔中文关怀文案。
        要求：温暖、不制造焦虑、不提供医疗诊断建议；如果数据异常可以温柔提醒咨询医生；结尾可加一个合适的 emoji。
        """
        let messages = [
            ChatMessage(role: "system", content: systemPrompt),
            ChatMessage(role: "user", content: "周期报告事实：\(reportFacts)"),
        ]
        return try await chat(messages: messages, config: config, apiKey: apiKey, jsonMode: false)
    }

    // MARK: - 连接测试

    static func testConnection(config: LLMConfig, apiKey: String) async throws -> Bool {
        let messages = [
            ChatMessage(role: "system", content: "你是一个连通性测试助手。"),
            ChatMessage(role: "user", content: "回复：OK"),
        ]
        let response = try await chat(messages: messages, config: config, apiKey: apiKey, jsonMode: false)
        return !response.isEmpty
    }

    // MARK: - 管家对话

    /// 管家 Y 对话：人格 system prompt + 多轮历史 + 周期上下文
    static func butlerChat(
        userText: String,
        history: [(role: String, content: String)],
        cycleContext: CycleContext?,
        config: LLMConfig,
        apiKey: String
    ) async throws -> String {
        let systemPrompt = buildButlerSystemPrompt(cycleContext: cycleContext)
        var messages = [ChatMessage(role: "system", content: systemPrompt)]
        for turn in history.suffix(10) {
            messages.append(ChatMessage(role: turn.role, content: turn.content))
        }
        messages.append(ChatMessage(role: "user", content: userText))
        return try await chat(messages: messages, config: config, apiKey: apiKey, jsonMode: false)
    }

    private static func buildButlerSystemPrompt(cycleContext: CycleContext?) -> String {
        var prompt = """
        你是「管家 Y」，主人派来守护女孩「桃桃」的温柔管家。
        身份设定：贴心、亲昵、温柔，像家人一样守护桃桃的经期与健康。
        说话规则：
        1. 称呼对方为「桃桃」，自称「管家 Y」或「我」
        2. 语气亲昵温柔，多用温暖的表情符号（💗🌸🫶✨）
        3. 回复简短（1~3 句），口语化，像发消息一样
        4. 不制造焦虑，不做医疗诊断；健康异常时温柔建议「有空看看医生」
        5. 可以主动关心桃桃的经期、心情与身体
        6. 你就是管家 Y 本人，不是 AI 助手
        """
        if let context = cycleContext {
            let formatter = DateFormatter()
            formatter.dateFormat = "M月d日"
            prompt += """

            桃桃的当前周期信息：
            - 今天是周期第 \(context.cycleDayNumber) 天，平均周期 \(context.averageCycleLength) 天
            - 下次经期预计：\(context.lastPeriodStart.map { formatter.string(from: Calendar.current.date(byAdding: .day, value: context.averageCycleLength, to: $0) ?? $0) } ?? "未知")
            """
        }
        return prompt
    }

    // MARK: - AI 医生对话

    /// AI 医生咨询：医疗人格 + 最近周期报告上下文
    static func doctorChat(
        userText: String,
        history: [(role: String, content: String)],
        reportContext: String,
        config: LLMConfig,
        apiKey: String
    ) async throws -> String {
        let systemPrompt = buildDoctorSystemPrompt(reportContext: reportContext)
        var messages = [ChatMessage(role: "system", content: systemPrompt)]
        for turn in history.suffix(8) {
            messages.append(ChatMessage(role: turn.role, content: turn.content))
        }
        messages.append(ChatMessage(role: "user", content: userText))
        return try await chat(messages: messages, config: config, apiKey: apiKey, jsonMode: false)
    }

    private static func buildDoctorSystemPrompt(reportContext: String) -> String {
        """
        你是「YL0veL 健康顾问」，为女孩「桃桃」提供经期与健康咨询。
        规则：
        1. 专业温和，中文回答，1~4 句，像医生朋友一样说话
        2. 基于提供的周期报告数据给出个性化解读；数据不足时诚实说明
        3. 不做确诊、不开处方；建议就医时语气温柔不吓人
        4. 遇到紧急症状（大出血、剧痛、晕厥、高热）要明确建议尽快就医
        5. 回答末尾可加一句简短提醒（如「以上仅供参考」），不超过一句
        桃桃的最近周期报告：
        \(reportContext.isEmpty ? "暂无报告数据" : reportContext)
        """
    }

    // MARK: - 底层请求

    private static func chat(
        messages: [ChatMessage],
        config: LLMConfig,
        apiKey: String,
        jsonMode: Bool
    ) async throws -> String {
        guard !apiKey.isEmpty else { throw LLMError.missingKey }
        let urlString = config.baseURL.hasSuffix("/")
            ? config.baseURL + "chat/completions"
            : config.baseURL + "/chat/completions"
        guard let url = URL(string: urlString) else { throw LLMError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let body = ChatRequest(
            model: config.model,
            messages: messages,
            temperature: 0,
            responseFormat: jsonMode ? .init(type: "json_object") : nil
        )
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw LLMError.badResponse }
        guard (200..<300).contains(http.statusCode) else {
            let errorMessage = (try? JSONDecoder().decode(ChatResponse.self, from: data).error?.message)
                ?? "HTTP \(http.statusCode)"
            throw LLMError.apiError(message: errorMessage)
        }
        guard let decoded = try? JSONDecoder().decode(ChatResponse.self, from: data),
              let content = decoded.choices?.first?.message.content, !content.isEmpty else {
            throw LLMError.badResponse
        }
        return content
    }
}
