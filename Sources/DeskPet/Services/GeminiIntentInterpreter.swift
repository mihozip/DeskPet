import Foundation

struct GeminiIntentInterpreter {
    enum InterpreterError: LocalizedError {
        case missingAPIKey
        case invalidResponse
        case httpError(Int, String)
        case blocked(String)
        case invalidDate(String)

        var errorDescription: String? {
            switch self {
            case .missingAPIKey:
                return "尚未設定 Gemini API Key"
            case .invalidResponse:
                return "Gemini 回傳格式無法解析"
            case .httpError(let code, let message):
                return "Gemini API 錯誤 \(code)：\(message)"
            case .blocked(let message):
                return "Gemini 未提供分析：\(message)"
            case .invalidDate(let value):
                return "AI 回傳的日期格式無法解析：\(value)"
            }
        }
    }

    private struct AIResult: Decodable {
        let kind: String
        let title: String
        let hasTargetDate: Bool
        let targetDatetime: String
        let confidence: Double
        let explanation: String

        enum CodingKeys: String, CodingKey {
            case kind
            case title
            case hasTargetDate = "has_target_date"
            case targetDatetime = "target_datetime"
            case confidence
            case explanation
        }
    }

    private struct APIResponse: Decodable {
        struct Candidate: Decodable {
            struct Content: Decodable {
                struct Part: Decodable {
                    let text: String?
                }

                let parts: [Part]?
            }

            let content: Content?
            let finishReason: String?
        }

        struct PromptFeedback: Decodable {
            let blockReason: String?
        }

        let candidates: [Candidate]?
        let promptFeedback: PromptFeedback?
    }

    private struct APIErrorEnvelope: Decodable {
        struct APIError: Decodable {
            let message: String
        }
        let error: APIError
    }

    private let configuration: AIConfigurationStore
    private let session: URLSession

    init(
        configuration: AIConfigurationStore,
        session: URLSession = .shared
    ) {
        self.configuration = configuration
        self.session = session
    }

    func interpret(text: String, referenceDate: Date = Date()) async throws -> SmartInterpretation {
        guard let apiKey = try await MainActor.run(body: { try configuration.apiKey() }),
              !apiKey.isEmpty else {
            throw InterpreterError.missingAPIKey
        }

        let modelID = await MainActor.run { configuration.modelID }
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(modelID):generateContent") else {
            throw InterpreterError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30
        request.httpBody = try makeRequestBody(text: text, referenceDate: referenceDate)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw InterpreterError.invalidResponse
        }

        guard (200...299).contains(http.statusCode) else {
            let message = (try? JSONDecoder().decode(APIErrorEnvelope.self, from: data).error.message)
                ?? String(data: data, encoding: .utf8)
                ?? "未知錯誤"
            throw InterpreterError.httpError(http.statusCode, message)
        }

        let envelope = try JSONDecoder().decode(APIResponse.self, from: data)

        if let reason = envelope.promptFeedback?.blockReason, !reason.isEmpty {
            throw InterpreterError.blocked(reason)
        }

        guard let candidate = envelope.candidates?.first,
              let parts = candidate.content?.parts,
              let jsonText = parts.compactMap(\.text).first(where: { !$0.isEmpty }),
              let jsonData = jsonText.data(using: .utf8) else {
            if let finishReason = envelope.candidates?.first?.finishReason, !finishReason.isEmpty {
                throw InterpreterError.blocked(finishReason)
            }
            throw InterpreterError.invalidResponse
        }

        let result = try JSONDecoder().decode(AIResult.self, from: jsonData)
        guard let kind = CaptureKind(rawValue: chineseKind(from: result.kind)) else {
            throw InterpreterError.invalidResponse
        }

        let targetDate: Date?
        if result.hasTargetDate {
            guard let date = parseISO8601(result.targetDatetime) else {
                throw InterpreterError.invalidDate(result.targetDatetime)
            }
            targetDate = date
        } else {
            targetDate = nil
        }

        let cleanTitle = result.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return SmartInterpretation(
            kind: kind,
            title: cleanTitle.isEmpty ? text : cleanTitle,
            targetDate: targetDate,
            confidence: min(max(result.confidence, 0), 1),
            explanation: result.explanation,
            source: .gemini
        )
    }

    private func chineseKind(from raw: String) -> String {
        switch raw.lowercased() {
        case "task": return "待辦"
        case "event": return "行程"
        default: return "記事"
        }
    }

    private func makeRequestBody(text: String, referenceDate: Date) throws -> Data {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withColonSeparatorInTimeZone]
        let now = formatter.string(from: referenceDate)
        let timezone = TimeZone.current.identifier

        let systemPrompt = """
        你是 DeskPet 的 Smart Inbox 解析器。將使用者的一句中文記事分類並抽取成結構化資料。

        類型只能是：
        - note：純記事、想法、資訊，沒有需要執行或出席的明確行動。
        - task：待辦、提醒、需要完成、確認、聯絡、回覆、查詢等行動。
        - event：會議、課程、約會、活動、拜訪、聚餐等需要在某段時間出席的行程。

        現在時間：\(now)
        使用者時區：\(timezone)

        日期規則：
        1. 正確解析今天、明天、後天、星期／週、下週、月日等相對日期。
        2. 「早上」若只有時段沒有時刻，預設 08:00；「下午」預設 15:00；「晚上」預設 19:00。
        3. 不要把沒有日期線索的內容自行加上日期。
        4. 若時間仍模糊到無法合理落到單一日期時間，has_target_date=false，target_datetime=""。
        5. 有日期時 target_datetime 必須是含時區的 RFC3339/ISO8601，例如 2026-08-03T15:00:00+08:00。
        6. 標題要移除「提醒我、記一下、明天、下午三點」等控制語與時間語，但保留事情本身。
        7. confidence 是 0 到 1；explanation 用繁體中文一句話簡要說明判斷依據。
        """

        let schema: [String: Any] = [
            "type": "object",
            "properties": [
                "kind": ["type": "string", "enum": ["note", "task", "event"]],
                "title": ["type": "string"],
                "has_target_date": ["type": "boolean"],
                "target_datetime": ["type": "string"],
                "confidence": ["type": "number", "minimum": 0, "maximum": 1],
                "explanation": ["type": "string"]
            ],
            "required": ["kind", "title", "has_target_date", "target_datetime", "confidence", "explanation"],
            "additionalProperties": false
        ]

        let body: [String: Any] = [
            "system_instruction": [
                "parts": [["text": systemPrompt]]
            ],
            "contents": [[
                "role": "user",
                "parts": [["text": text]]
            ]],
            "generationConfig": [
                "maxOutputTokens": 300,
                "responseMimeType": "application/json",
                "responseJsonSchema": schema
            ]
        ]

        return try JSONSerialization.data(withJSONObject: body)
    }

    private func parseISO8601(_ value: String) -> Date? {
        let standard = ISO8601DateFormatter()
        standard.formatOptions = [.withInternetDateTime, .withColonSeparatorInTimeZone]
        if let date = standard.date(from: value) {
            return date
        }

        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds, .withColonSeparatorInTimeZone]
        return fractional.date(from: value)
    }
}
