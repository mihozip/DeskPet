import Foundation

struct NaturalTaskActionInterpreter {
    enum InterpretationError: LocalizedError {
        case emptyCommand
        case noTasks
        case couldNotInferAction
        case couldNotMatchTask
        case missingDateForPostpone

        var errorDescription: String? {
            switch self {
            case .emptyCommand: return "請先輸入一句描述，例如：冷氣廠商回覆了。"
            case .noTasks: return "目前還沒有可操作的總務任務，請先同步總務工作台。"
            case .couldNotInferAction: return "暫時看不出是要完成、收到回覆，還是延期。"
            case .couldNotMatchTask: return "找不到最適合的任務，請在句子中放入更明確的任務名稱。"
            case .missingDateForPostpone: return "有辨識到延期，但沒有找到新的日期時間。"
            }
        }
    }

    private let localInterpreter: LocalIntentInterpreter

    init(localInterpreter: LocalIntentInterpreter = LocalIntentInterpreter()) {
        self.localInterpreter = localInterpreter
    }

    func interpret(command: String, tasks: [GASTaskDigest.Task], referenceDate: Date = Date()) throws -> NaturalTaskActionProposal {
        let text = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw InterpretationError.emptyCommand }
        guard !tasks.isEmpty else { throw InterpretationError.noTasks }

        let action = try inferAction(from: text)
        let task = try matchTask(for: text, tasks: tasks)

        var dueDate: Date?
        if action == .postpone {
            let interpreted = localInterpreter.interpret(text: text, referenceDate: referenceDate)
            dueDate = interpreted.targetDate
            if dueDate == nil { throw InterpretationError.missingDateForPostpone }
        }

        let note = defaultNote(for: action, command: text, task: task)
        let confidence = confidence(for: text, task: task, action: action)
        let explanation = explanation(for: task, action: action, dueDate: dueDate)

        return NaturalTaskActionProposal(
            commandText: text,
            task: task,
            action: action,
            note: note,
            dueDate: dueDate,
            explanation: explanation,
            confidence: confidence,
            source: .local
        )
    }

    private func inferAction(from text: String) throws -> GASTaskMutationKind {
        let normalized = text.replacingOccurrences(of: "已經", with: "")

        let completeKeywords = ["完成", "做完", "好了", "搞定", "結案", "處理好了", "完成了"]
        if completeKeywords.contains(where: normalized.contains) {
            return .complete
        }

        let replyKeywords = ["收到回覆", "有回覆", "回覆了", "回來了", "回信了", "已回覆", "收到廠商回覆", "有消息"]
        if replyKeywords.contains(where: normalized.contains) {
            return .receivedReply
        }

        let postponeKeywords = ["延期", "延到", "延至", "延後", "改到", "改成", "順延", "挪到"]
        if postponeKeywords.contains(where: normalized.contains) {
            return .postpone
        }

        throw InterpretationError.couldNotInferAction
    }

    private func matchTask(for text: String, tasks: [GASTaskDigest.Task]) throws -> GASTaskDigest.Task {
        let scored = tasks.map { task in (task, score(text: text, task: task)) }
        guard let best = scored.max(by: { $0.1 < $1.1 }) else { throw InterpretationError.couldNotMatchTask }
        let threshold = min(12, max(4, best.1 / 2))
        guard best.1 >= threshold else { throw InterpretationError.couldNotMatchTask }
        return best.0
    }

    private func score(text: String, task: GASTaskDigest.Task) -> Int {
        var score = 0
        let corpus = [task.name, task.nextAction ?? "", task.waitingFor ?? "", task.category ?? ""].joined(separator: " ")

        if text.contains(task.name) { score += 120 }
        if let next = task.nextAction, !next.isEmpty, text.contains(next) { score += 80 }
        if let waiting = task.waitingFor, !waiting.isEmpty, text.contains(waiting) { score += 45 }
        if let category = task.category, !category.isEmpty, text.contains(category) { score += 18 }

        score += longestCommonChunk(between: text, and: task.name) * 18
        if let next = task.nextAction { score += longestCommonChunk(between: text, and: next) * 10 }

        let keywords = extractKeywords(from: corpus)
        for keyword in keywords where text.contains(keyword) {
            score += keyword.count >= 3 ? 15 : 8
        }

        if task.isOverdue && text.contains("逾期") { score += 12 }
        if task.isWaiting && (text.contains("等待") || text.contains("回覆")) { score += 8 }
        return score
    }

    private func longestCommonChunk(between lhs: String, and rhs: String) -> Int {
        let a = Array(lhs)
        let b = Array(rhs)
        var best = 0
        guard !a.isEmpty, !b.isEmpty else { return 0 }

        for i in 0..<a.count {
            for j in 0..<b.count {
                var length = 0
                while i + length < a.count, j + length < b.count, a[i + length] == b[j + length] {
                    length += 1
                    best = max(best, length)
                }
            }
        }
        return best
    }

    private func extractKeywords(from text: String) -> [String] {
        let punctuation = CharacterSet(charactersIn: "，,。.!！?？：:；;（）()[]【】<>《》/|")
        let separators = CharacterSet.whitespacesAndNewlines.union(punctuation)
        let pieces = text.components(separatedBy: separators)
        return pieces.filter { $0.count >= 2 }
    }

    private func defaultNote(for action: GASTaskMutationKind, command: String, task: GASTaskDigest.Task) -> String {
        switch action {
        case .complete:
            return "DeskPet 自然語句：\(command)"
        case .receivedReply:
            if command.contains("回覆") || command.contains("回信") || command.contains("消息") {
                return command
            }
            return "已收到回覆，轉回進行中"
        case .postpone:
            return "DeskPet 自然語句：\(command)"
        }
    }

    private func explanation(for task: GASTaskDigest.Task, action: GASTaskMutationKind, dueDate: Date?) -> String {
        switch action {
        case .complete:
            return "將「\(task.name)」標記為已完成，並保留一則進度紀錄。"
        case .receivedReply:
            return "將「\(task.name)」從等待狀態轉回進行中，並清除等待對象。"
        case .postpone:
            let formatted = dueDate.map { Self.dateTimeFormatter.string(from: $0) } ?? "新的日期"
            return "將「\(task.name)」延期到 \(formatted)。"
        }
    }

    private func confidence(for text: String, task: GASTaskDigest.Task, action: GASTaskMutationKind) -> Double {
        var base = 0.72
        if text.contains(task.name) { base += 0.12 }
        if action == .postpone { base += 0.06 }
        if task.isWaiting && action == .receivedReply { base += 0.06 }
        return min(base, 0.96)
    }

    private static let dateTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_TW")
        f.timeZone = TimeZone(identifier: "Asia/Taipei")
        f.dateFormat = "yyyy/MM/dd HH:mm"
        return f
    }()
}
