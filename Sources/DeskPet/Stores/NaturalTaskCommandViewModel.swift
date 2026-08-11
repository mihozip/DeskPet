import Foundation

@MainActor
final class NaturalTaskCommandViewModel: ObservableObject {
    @Published var commandText = ""
    @Published private(set) var proposal: NaturalTaskActionProposal?
    @Published private(set) var ambiguity: NaturalTaskActionAmbiguity?
    @Published private(set) var statusMessage = "輸入一句話，例如：冷氣廠商回覆了。"
    @Published private(set) var isAnalyzing = false
    @Published private(set) var usedFallback = false

    private let monitor: GASTaskAmbientMonitor
    private let connector: GASTaskConnector
    private let aiConfiguration: AIConfigurationStore
    private let localInterpreter: NaturalTaskActionInterpreter
    private let geminiInterpreter: GeminiNaturalTaskActionInterpreter
    private let onOpenInteraction: (GASTaskDigest.Task, GASTaskMutationKind, String, Date?, String?) -> Void

    init(
        monitor: GASTaskAmbientMonitor,
        connector: GASTaskConnector,
        aiConfiguration: AIConfigurationStore,
        localInterpreter: NaturalTaskActionInterpreter = NaturalTaskActionInterpreter(),
        geminiInterpreter: GeminiNaturalTaskActionInterpreter? = nil,
        onOpenInteraction: @escaping (GASTaskDigest.Task, GASTaskMutationKind, String, Date?, String?) -> Void
    ) {
        self.monitor = monitor
        self.connector = connector
        self.aiConfiguration = aiConfiguration
        self.localInterpreter = localInterpreter
        self.geminiInterpreter = geminiInterpreter ?? GeminiNaturalTaskActionInterpreter(configuration: aiConfiguration)
        self.onOpenInteraction = onOpenInteraction
    }

    var analysisModeLabel: String {
        if aiConfiguration.canUseAI {
            return "Gemini \(aiConfiguration.modelID) + 本機 fallback"
        }
        return "本機規則（Gemini 未啟用）"
    }

    var administrativeTitle: String { monitor.administrativeTitle }

    func analyze() async {
        let text = commandText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            statusMessage = "請先輸入一句話。"
            proposal = nil
            ambiguity = nil
            return
        }

        isAnalyzing = true
        usedFallback = false
        proposal = nil
        ambiguity = nil
        statusMessage = aiConfiguration.canUseAI ? "DeskPet 正在用 Gemini 理解這句話…" : "DeskPet 正在用本機規則分析…"
        defer { isAnalyzing = false }

        let tasks: [GASTaskDigest.Task]
        do {
            // 自然語句操作比 Ambient 摘要需要更寬的候選集合，因此直接取 Gateway 允許的上限 30 筆。
            let digest = try await connector.fetchTaskDigest(limit: 30)
            tasks = digest.tasks
        } catch {
            if let cached = monitor.digest?.tasks, !cached.isEmpty {
                tasks = cached
                statusMessage = "即時同步失敗，先使用最近一次任務摘要。"
            } else {
                statusMessage = "無法取得可操作任務：\(error.localizedDescription)"
                return
            }
        }

        guard !tasks.isEmpty else {
            statusMessage = "目前沒有可操作的\(administrativeTitle)任務。"
            return
        }

        if aiConfiguration.canUseAI {
            do {
                let resolution = try await geminiInterpreter.interpret(command: text, tasks: tasks)
                applyGeminiResolution(resolution, command: text)
                return
            } catch {
                usedFallback = true
                let aiError = error.localizedDescription
                do {
                    let local = try localInterpreter.interpret(command: text, tasks: tasks)
                    proposal = local
                    statusMessage = "Gemini 暫時失敗，已改用本機解析：\(aiError)"
                    return
                } catch {
                    statusMessage = "Gemini 與本機解析都無法確定：\(error.localizedDescription)"
                    return
                }
            }
        }

        do {
            let local = try localInterpreter.interpret(command: text, tasks: tasks)
            proposal = local
            statusMessage = local.explanation
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func useExample(_ example: String) {
        commandText = example
        proposal = nil
        ambiguity = nil
        statusMessage = "已套用範例，按「分析這句話」。"
    }

    func chooseCandidate(_ task: GASTaskDigest.Task) {
        guard let ambiguity else { return }

        if let action = ambiguity.action {
            if action == .postpone, ambiguity.dueDate == nil {
                statusMessage = "已選定「\(task.name)」，但新的延期日期仍不明確。"
                return
            }
            proposal = NaturalTaskActionProposal(
                commandText: commandText,
                task: task,
                action: action,
                note: ambiguity.note.isEmpty ? "DeskPet 自然語句：\(commandText)" : ambiguity.note,
                dueDate: ambiguity.dueDate,
                nextAction: ambiguity.nextAction,
                explanation: "你已手動指定「\(task.name)」。\(ambiguity.message)",
                confidence: max(ambiguity.confidence, 0.90),
                source: ambiguity.source
            )
            self.ambiguity = nil
            statusMessage = proposal?.explanation ?? "已選定任務。"
            return
        }

        do {
            let local = try localInterpreter.interpret(command: commandText, tasks: [task])
            proposal = NaturalTaskActionProposal(
                commandText: local.commandText,
                task: task,
                action: local.action,
                note: local.note,
                dueDate: local.dueDate,
                nextAction: local.nextAction,
                explanation: "你已手動指定「\(task.name)」。\(local.explanation)",
                confidence: max(local.confidence, 0.90),
                source: ambiguity.source
            )
            self.ambiguity = nil
            statusMessage = proposal?.explanation ?? "已選定任務。"
        } catch {
            statusMessage = "已選定任務，但操作仍不夠明確：\(error.localizedDescription)"
        }
    }

    func proceed() {
        guard let proposal else { return }
        onOpenInteraction(proposal.task, proposal.action, proposal.note, proposal.dueDate, proposal.nextAction)
    }

    private func applyGeminiResolution(
        _ resolution: GeminiNaturalTaskActionInterpreter.Resolution,
        command: String
    ) {
        switch resolution.matchStatus {
        case .matched:
            guard let task = resolution.matchedTask else {
                statusMessage = "Gemini 回傳的任務 ID 不在目前任務清單中，為避免誤寫入已停止。"
                return
            }
            guard resolution.confidence >= 0.70 else {
                statusMessage = "Gemini 只以 \(Int(resolution.confidence * 100))% 信心指向「\(task.name)」，低於安全門檻；請加入更多任務線索後重試。"
                return
            }
            guard let action = resolution.action else {
                statusMessage = "Gemini 找到任務「\(task.name)」，但無法確定要做的操作。"
                return
            }
            if action == .postpone, resolution.dueDate == nil {
                statusMessage = "Gemini 判斷要延期「\(task.name)」，但新的日期不夠明確，請把日期說清楚。"
                return
            }

            proposal = NaturalTaskActionProposal(
                commandText: command,
                task: task,
                action: action,
                note: resolution.note.isEmpty ? "DeskPet 自然語句：\(command)" : resolution.note,
                dueDate: resolution.dueDate,
                nextAction: resolution.nextAction,
                explanation: resolution.explanation,
                confidence: resolution.confidence,
                source: .gemini
            )
            statusMessage = resolution.explanation

        case .ambiguous:
            let candidates = resolution.candidateTasks
            ambiguity = NaturalTaskActionAmbiguity(
                message: resolution.explanation.isEmpty ? "這句話可能對應多筆任務，請先選一筆。" : resolution.explanation,
                candidates: candidates,
                action: resolution.action,
                note: resolution.note,
                dueDate: resolution.dueDate,
                nextAction: resolution.nextAction,
                confidence: resolution.confidence,
                source: .gemini
            )
            statusMessage = ambiguity?.message ?? "需要你協助選擇任務。"

        case .noMatch:
            statusMessage = resolution.explanation.isEmpty
                ? "Gemini 找不到合理對應的任務，請加入任務名稱或更多線索。"
                : resolution.explanation
        }
    }
}
