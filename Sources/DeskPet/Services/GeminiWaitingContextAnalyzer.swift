import Foundation

struct GeminiWaitingContextAnalyzer {
    enum AnalyzerError: LocalizedError {
        case missingAPIKey
        case aiDisabled
        case invalidResponse
        case httpError(Int, String)
        case blocked(String)

        var errorDescription: String? {
            switch self {
            case .missingAPIKey: return "尚未設定 Gemini API Key"
            case .aiDisabled: return "AI 功能尚未啟用"
            case .invalidResponse: return "Gemini 回傳的等待情境格式無法解析"
            case .httpError(let code, let message): return "Gemini API 錯誤 \(code)：\(message)"
            case .blocked(let message): return "Gemini 未提供等待情境分析：\(message)"
            }
        }
    }

    private struct AIResult: Decodable {
        let contextualRiskDelta: Int
        let blockingImpact: String
        let dependencySummary: String
        let riskSignals: [String]
        let rationale: String
        let recommendedAction: String
        let confidence: Double

        enum CodingKeys: String, CodingKey {
            case contextualRiskDelta = "contextual_risk_delta"
            case blockingImpact = "blocking_impact"
            case dependencySummary = "dependency_summary"
            case riskSignals = "risk_signals"
            case rationale
            case recommendedAction = "recommended_action"
            case confidence
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

        struct PromptFeedback: Decodable {
            let blockReason: String?
        }

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

    func analyze(
        item: WaitingItem,
        peerTasks: [GASTaskDigest.Task],
        referenceDate: Date = Date()
    ) async throws -> WaitingAIContextAssessment {
        let canUseAI = await MainActor.run { configuration.canUseAI }
        guard canUseAI else {
            let hasKey = await MainActor.run { configuration.hasAPIKey }
            throw hasKey ? AnalyzerError.aiDisabled : AnalyzerError.missingAPIKey
        }

        guard let apiKey = try await MainActor.run(body: { try configuration.apiKey() }), !apiKey.isEmpty else {
            throw AnalyzerError.missingAPIKey
        }
        let modelID = await MainActor.run { configuration.modelID }
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(modelID):generateContent") else {
            throw AnalyzerError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30
        request.httpBody = try makeRequestBody(item: item, peerTasks: peerTasks, referenceDate: referenceDate)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw AnalyzerError.invalidResponse }
        guard (200...299).contains(http.statusCode) else {
            let message = (try? JSONDecoder().decode(APIErrorEnvelope.self, from: data).error.message)
                ?? String(data: data, encoding: .utf8)
                ?? "未知錯誤"
            throw AnalyzerError.httpError(http.statusCode, message)
        }

        let envelope = try JSONDecoder().decode(APIResponse.self, from: data)
        if let reason = envelope.promptFeedback?.blockReason, !reason.isEmpty {
            throw AnalyzerError.blocked(reason)
        }
        guard let candidate = envelope.candidates?.first,
              let parts = candidate.content?.parts else {
            throw AnalyzerError.invalidResponse
        }
        if candidate.finishReason == "MAX_TOKENS" {
            throw AnalyzerError.blocked("Gemini 回應因輸出長度不足而被截斷")
        }
        guard let jsonText = GeminiResponseParser.finalAnswerText(from: parts) else {
            throw AnalyzerError.invalidResponse
        }

        let result = try GeminiResponseParser.decodeStructuredOutput(AIResult.self, from: jsonText)
        guard let blockingImpact = WaitingBlockingImpact(rawValue: result.blockingImpact.lowercased()) else {
            throw AnalyzerError.invalidResponse
        }

        return WaitingAIContextAssessment(
            taskID: item.task.taskId,
            sourceFingerprint: WaitingAIContextAssessment.fingerprint(for: item),
            contextualRiskDelta: Self.normalizedRiskDelta(result.contextualRiskDelta),
            blockingImpact: blockingImpact,
            dependencySummary: Self.cleaned(result.dependencySummary),
            riskSignals: Array(result.riskSignals.map(Self.cleaned).filter { !$0.isEmpty }.prefix(4)),
            rationale: Self.cleaned(result.rationale),
            recommendedAction: Self.cleaned(result.recommendedAction),
            confidence: min(1, max(0, result.confidence)),
            assessedAt: referenceDate
        )
    }

    static func normalizedRiskDelta(_ value: Int) -> Int {
        min(25, max(-15, value))
    }

    private func makeRequestBody(
        item: WaitingItem,
        peerTasks: [GASTaskDigest.Task],
        referenceDate: Date
    ) throws -> Data {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withColonSeparatorInTimeZone]
        let now = formatter.string(from: referenceDate)
        let task = item.task
        let peerSummary = peerTasks
            .filter { $0.taskId != task.taskId }
            .prefix(12)
            .map { peer in
                "- \(peer.name)｜類別：\(peer.category ?? "未填")｜狀態：\(peer.status ?? "未填")｜截止：\(peer.deadlineText ?? "未填")｜下一步：\(peer.nextAction ?? "未填")"
            }
            .joined(separator: "\n")

        let userContext = """
        【目前等待案件】
        任務：\(task.name)
        類別：\(task.category ?? "未填")
        狀態：\(task.status ?? "未填")
        優先度：\(task.priority ?? "未填")
        截止：\(task.deadlineText ?? "未填")
        等待對象：\(item.waitingTarget.isEmpty ? "未填" : item.waitingTarget)
        已等待：\(item.waitingDays) 天
        已催辦：\(item.followUpCount) 次
        規則風險：\(item.riskScore)/100（\(item.riskLevel.label)）
        下一步：\(task.nextAction ?? "未填")
        最近進度：\(task.progress ?? "未填")

        【其他目前工作，僅供判斷可能的依賴或阻塞】
        \(peerSummary.isEmpty ? "無可用資料" : peerSummary)
        """

        let systemPrompt = """
        你是 DeskPet 的 Waiting Intelligence 情境分析器。現在時間：\(now)。

        你的任務不是取代規則引擎，而是補充規則難以理解的語意情境。規則風險分數是可驗證的第一層；你只能提供「情境加權」與理由。

        請評估：
        1. 這個等待是否可能阻塞後續行政流程；
        2. 任務文字、下一步、最近進度與其他工作是否顯示依賴關係；
        3. 是否有規則分數沒有捕捉到的時程、交接或流程風險；
        4. 今天是否值得優先人工追蹤。

        嚴格限制：
        - 不得假設未提供的法規、期限、承諾、人物關係或組織流程。
        - 證據不足時 contextual_risk_delta 應接近 0，confidence 應降低。
        - contextual_risk_delta 只能介於 -15 到 +25。正值代表語意情境顯示比規則層更值得關注；負值只可在明確有緩衝或低阻塞證據時使用。
        - blocking_impact 只能是 low、medium、high。
        - risk_signals 最多 4 項，每項用繁體中文短句，必須可由輸入內容直接支持。
        - dependency_summary 若沒有足夠證據，請明確寫「未發現可確認的後續依賴」。
        - recommended_action 必須是給人的建議，不可聲稱已經修改任務、催辦、寄信或完成任何操作。
        - 不要要求或產生任何自動寫入行為。
        """

        let schema: [String: Any] = [
            "type": "object",
            "properties": [
                "contextual_risk_delta": ["type": "integer", "minimum": -15, "maximum": 25],
                "blocking_impact": ["type": "string", "enum": ["low", "medium", "high"]],
                "dependency_summary": ["type": "string"],
                "risk_signals": ["type": "array", "items": ["type": "string"], "maxItems": 4],
                "rationale": ["type": "string"],
                "recommended_action": ["type": "string"],
                "confidence": ["type": "number", "minimum": 0, "maximum": 1]
            ],
            "required": [
                "contextual_risk_delta", "blocking_impact", "dependency_summary",
                "risk_signals", "rationale", "recommended_action", "confidence"
            ],
            "additionalProperties": false
        ]

        let body: [String: Any] = [
            "system_instruction": ["parts": [["text": systemPrompt]]],
            "contents": [["role": "user", "parts": [["text": userContext]]]],
            "generationConfig": [
                "maxOutputTokens": 1800,
                "thinkingConfig": ["thinkingLevel": "minimal"],
                "responseMimeType": "application/json",
                "responseJsonSchema": schema
            ]
        ]
        return try JSONSerialization.data(withJSONObject: body)
    }

    private static func cleaned(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
