import Foundation

struct GeminiNaturalTaskActionInterpreter {
    enum MatchStatus: String, Decodable {
        case matched
        case ambiguous
        case noMatch = "no_match"
    }

    struct Resolution {
        let matchStatus: MatchStatus
        let matchedTask: GASTaskDigest.Task?
        let candidateTasks: [GASTaskDigest.Task]
        let action: GASTaskMutationKind?
        let dueDate: Date?
        let note: String
        let nextAction: String?
        let confidence: Double
        let explanation: String
    }

    enum InterpreterError: LocalizedError {
        case missingAPIKey
        case invalidResponse
        case httpError(Int, String)
        case blocked(String)
        case invalidDate(String)

        var errorDescription: String? {
            switch self {
            case .missingAPIKey: return "尚未設定 Gemini API Key"
            case .invalidResponse: return "Gemini 自然語句解析結果無法辨識"
            case .httpError(let code, let message): return "Gemini API 錯誤 \(code)：\(message)"
            case .blocked(let message): return "Gemini 未提供分析：\(message)"
            case .invalidDate(let value): return "Gemini 回傳的日期格式無法解析：\(value)"
            }
        }
    }

    private struct AIResult: Decodable {
        let matchStatus: MatchStatus
        let taskId: String
        let candidateTaskIds: [String]
        let action: String
        let hasDueDatetime: Bool
        let dueDatetime: String
        let note: String
        let nextAction: String?
        let confidence: Double
        let explanation: String

        enum CodingKeys: String, CodingKey {
            case matchStatus = "match_status"
            case taskId = "task_id"
            case candidateTaskIds = "candidate_task_ids"
            case action
            case hasDueDatetime = "has_due_datetime"
            case dueDatetime = "due_datetime"
            case note
            case nextAction = "next_action"
            case confidence
            case explanation
        }
    }

    private struct APIResponse: Decodable {
        struct Candidate: Decodable {
            struct Content: Decodable {
                typealias Part = GeminiResponseParser.TextPart
                let parts: [Part]?
            }
            let content: Content?
            let finishReason: String?
        }

        struct PromptFeedback: Decodable { let blockReason: String? }
        let candidates: [Candidate]?
        let promptFeedback: PromptFeedback?
    }

    private struct APIErrorEnvelope: Decodable {
        struct APIError: Decodable { let message: String }
        let error: APIError
    }

    private let configuration: AIConfigurationStore
    private let session: URLSession

    init(configuration: AIConfigurationStore, session: URLSession = .shared) {
        self.configuration = configuration
        self.session = session
    }

    func interpret(
        command: String,
        tasks: [GASTaskDigest.Task],
        referenceDate: Date = Date()
    ) async throws -> Resolution {
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
        request.httpBody = try makeRequestBody(command: command, tasks: tasks, referenceDate: referenceDate)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw InterpreterError.invalidResponse }

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
              let parts = candidate.content?.parts else {
            if let finishReason = envelope.candidates?.first?.finishReason, !finishReason.isEmpty {
                throw InterpreterError.blocked(finishReason)
            }
            throw InterpreterError.invalidResponse
        }

        if candidate.finishReason == "MAX_TOKENS" {
            throw InterpreterError.blocked("Gemini 回應因輸出長度不足而被截斷，請再試一次")
        }

        guard let jsonText = GeminiResponseParser.finalAnswerText(from: parts) else {
            if let finishReason = candidate.finishReason, !finishReason.isEmpty, finishReason != "STOP" {
                throw InterpreterError.blocked(finishReason)
            }
            throw GeminiResponseParser.ParseError.missingAnswer
        }

        let result = try GeminiResponseParser.decodeStructuredOutput(AIResult.self, from: jsonText)
        let taskMap = Dictionary(uniqueKeysWithValues: tasks.map { ($0.taskId, $0) })
        let matchedTask = taskMap[result.taskId]
        let candidates = result.candidateTaskIds.compactMap { taskMap[$0] }
        let action = actionKind(from: result.action)

        let dueDate: Date?
        if result.hasDueDatetime {
            guard let parsed = parseISO8601(result.dueDatetime) else {
                throw InterpreterError.invalidDate(result.dueDatetime)
            }
            dueDate = parsed
        } else {
            dueDate = nil
        }

        return Resolution(
            matchStatus: result.matchStatus,
            matchedTask: matchedTask,
            candidateTasks: candidates,
            action: action,
            dueDate: dueDate,
            note: result.note.trimmingCharacters(in: .whitespacesAndNewlines),
            nextAction: result.nextAction?.trimmingCharacters(in: .whitespacesAndNewlines),
            confidence: min(max(result.confidence, 0), 1),
            explanation: result.explanation
        )
    }

    private func actionKind(from raw: String) -> GASTaskMutationKind? {
        switch raw {
        case "complete": return .complete
        case "received_reply": return .receivedReply
        case "postpone": return .postpone
        case "update_progress": return .updateProgress
        default: return nil
        }
    }

    private func makeRequestBody(command: String, tasks: [GASTaskDigest.Task], referenceDate: Date) throws -> Data {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withColonSeparatorInTimeZone]
        let now = formatter.string(from: referenceDate)
        let timezone = TimeZone.current.identifier

        let taskContext = tasks.map { task -> [String: Any] in
            [
                "task_id": task.taskId,
                "name": task.name,
                "category": task.category ?? "",
                "status": task.status ?? "",
                "priority": task.priority ?? "",
                "due_date": task.dueDate ?? "",
                "due_time": task.dueTime ?? "",
                "next_action": task.nextAction ?? "",
                "waiting_for": task.waitingFor ?? "",
                "progress": task.progress ?? ""
            ]
        }
        let taskData = try JSONSerialization.data(withJSONObject: taskContext, options: [.sortedKeys])
        let taskJSON = String(data: taskData, encoding: .utf8) ?? "[]"

        let systemPrompt = """
        你是 DeskPet 0.7 的行政任務代理解析器。你只負責「理解與提出變更草案」，不得自行執行。

        現在時間：\(now)
        使用者時區：\(timezone)

        你會收到：
        1. 使用者的一句自然中文，例如「那個冷氣的延到星期五下午」、「廠商那件回覆了」。
        2. 一組目前可操作的行政任務。

        你必須同時判斷：
        A. 使用者指的是哪一筆既有任務。
        B. 想做哪一種操作。
        C. 若為延期，要解析新的日期時間。

        操作只能是：
        - complete：任務已完成。
        - received_reply：原本等待他人／待確認的事項已收到回覆，應轉回進行中並清除等待對象。
        - postpone：調整截止日期／時間。
        - update_progress：更新最近進度與下一步行動。
        - unknown：無法確定操作。

        任務匹配規則：
        1. task_id 必須原封不動地使用提供的 task_id，絕對不能自行創造 ID。
        2. 可以綜合 name、category、next_action、waiting_for、progress、期限與狀態理解「那件」、「廠商那個」、「冷氣的」等省略說法。
        3. 只有一筆明顯最符合時 match_status=matched。
        4. 若有兩筆以上合理候選且無法可靠區分，match_status=ambiguous，task_id=""，candidate_task_ids 放最多 3 個真正候選 ID。
        5. 找不到合理任務時 match_status=no_match。
        6. 不得因為方便而硬猜。低於約 0.70 信心時優先 ambiguous 或 no_match。

        日期規則：
        1. 正確解析今天、明天、星期／週、下週、月日等相對日期。
        2. 只有「下午」沒有明確時刻時預設 15:00；早上 08:00；晚上 19:00。
        3. postpone 若沒有足夠日期資訊，action 仍可為 postpone，但 has_due_datetime=false。
        4. due_datetime 有值時必須為含時區 RFC3339，例如 2026-08-07T15:00:00+08:00。

        note 請用繁體中文產生簡短、可直接作為「最近進度」的紀錄，不要加入虛構細節。
        explanation 用一句繁體中文說明為何匹配這筆任務與操作。

        可操作任務 JSON：
        \(taskJSON)
        """

        let schema: [String: Any] = [
            "type": "object",
            "properties": [
                "match_status": ["type": "string", "enum": ["matched", "ambiguous", "no_match"]],
                "task_id": ["type": "string"],
                "candidate_task_ids": ["type": "array", "items": ["type": "string"], "maxItems": 3],
                "action": ["type": "string", "enum": ["complete", "received_reply", "postpone", "update_progress", "unknown"]],
                "has_due_datetime": ["type": "boolean"],
                "due_datetime": ["type": "string"],
                "note": ["type": "string"],
                "next_action": ["type": "string"],
                "confidence": ["type": "number", "minimum": 0, "maximum": 1],
                "explanation": ["type": "string"]
            ],
            "required": [
                "match_status", "task_id", "candidate_task_ids", "action",
                "has_due_datetime", "due_datetime", "note", "next_action", "confidence", "explanation"
            ],
            "additionalProperties": false
        ]

        let body: [String: Any] = [
            "system_instruction": ["parts": [["text": systemPrompt]]],
            "contents": [[
                "role": "user",
                "parts": [["text": command]]
            ]],
            "generationConfig": [
                "maxOutputTokens": 1800,
                "thinkingConfig": ["thinkingLevel": "minimal"],
                "responseMimeType": "application/json",
                "responseJsonSchema": schema
            ]
        ]

        return try JSONSerialization.data(withJSONObject: body)
    }

    private func parseISO8601(_ value: String) -> Date? {
        let standard = ISO8601DateFormatter()
        standard.formatOptions = [.withInternetDateTime, .withColonSeparatorInTimeZone]
        if let date = standard.date(from: value) { return date }

        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds, .withColonSeparatorInTimeZone]
        return fractional.date(from: value)
    }
}
