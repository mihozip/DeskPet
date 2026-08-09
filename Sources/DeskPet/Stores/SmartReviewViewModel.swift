import Combine
import Foundation

@MainActor
final class SmartReviewViewModel: ObservableObject {
    @Published var kind: CaptureKind
    @Published var title: String
    @Published var hasTargetDate: Bool
    @Published var targetDate: Date
    @Published var gasCategory: String
    @Published var gasPriority: String
    @Published private(set) var confidence: Double
    @Published private(set) var explanation: String
    @Published private(set) var source: InterpretationSource?
    @Published private(set) var isAIAnalyzing = false
    @Published private(set) var aiStatusMessage: String?
    @Published private(set) var isExecutingAction = false
    @Published private(set) var actionStatusMessage: String?
    @Published private(set) var actionReceipts: [ActionReceipt]
    @Published private(set) var duplicateCandidates: [DuplicateCandidate] = []
    @Published private(set) var duplicateCheckMessage: String?
    @Published private(set) var isCheckingDuplicates = false

    let originalText: String

    private let itemID: UUID
    private let store: CaptureStore
    private let localInterpreter: LocalIntentInterpreter
    private let aiInterpreter: GeminiIntentInterpreter
    private let aiConfiguration: AIConfigurationStore
    private let actionService: CalendarActionService
    private let gasConfiguration: GASTaskConfigurationStore
    private let gasConnector: GASTaskConnector
    private let workEventStore: WorkEventStore
    private let duplicateGuard = DuplicateGuardService()

    init(
        item: CaptureItem,
        store: CaptureStore,
        localInterpreter: LocalIntentInterpreter,
        aiInterpreter: GeminiIntentInterpreter,
        aiConfiguration: AIConfigurationStore,
        actionService: CalendarActionService,
        gasConfiguration: GASTaskConfigurationStore,
        gasConnector: GASTaskConnector,
        workEventStore: WorkEventStore
    ) {
        itemID = item.id
        originalText = item.text
        self.store = store
        self.localInterpreter = localInterpreter
        self.aiInterpreter = aiInterpreter
        self.aiConfiguration = aiConfiguration
        self.actionService = actionService
        self.gasConfiguration = gasConfiguration
        self.gasConnector = gasConnector
        self.workEventStore = workEventStore
        actionReceipts = item.actionReceipts

        let interpretation = item.interpretation ?? localInterpreter.interpret(text: item.text)
        kind = interpretation.kind
        title = interpretation.title
        hasTargetDate = interpretation.targetDate != nil
        targetDate = interpretation.targetDate ?? Date()
        confidence = interpretation.confidence
        explanation = interpretation.explanation
        source = interpretation.source
        gasCategory = interpretation.taskCategory ?? GASTaskTaxonomy.inferredCategory(from: item.text)
        gasPriority = interpretation.taskPriority ?? GASTaskTaxonomy.inferredPriority(from: item.text)

        if !item.actionReceipts.isEmpty {
            actionStatusMessage = "已建立：" + item.actionReceipts.map { $0.kind.displayName }.joined(separator: "、")
        }

        if item.interpretation == nil && item.actionReceipts.isEmpty && aiConfiguration.canUseAI {
            Task { [weak self] in await self?.analyzeWithAI() }
        }
    }

    var confidenceLabel: String { "\(Int((confidence * 100).rounded()))%" }

    var sourceLabel: String {
        switch source {
        case .gemini: return "Gemini AI 分析"
        case .openAI: return "舊版 OpenAI 分析"
        case .manual: return "人工指定"
        case .local: return "本機分析"
        case .none: return "已儲存結果"
        }
    }

    var canUseAI: Bool { aiConfiguration.canUseAI && actionReceipts.isEmpty }
    var isLockedAfterAction: Bool { !actionReceipts.isEmpty }
    var gasCategories: [String] { GASTaskTaxonomy.categories }
    var gasPriorities: [String] { GASTaskTaxonomy.priorities }
    var canUseGASConnector: Bool { gasConfiguration.canUseConnector }

    func hasReceipt(_ kind: DeskPetActionKind) -> Bool {
        actionReceipts.contains(where: { $0.kind == kind })
    }

    var canCreateReminder: Bool {
        kind == .task && !hasReceipt(.reminder) && !isExecutingAction
    }

    var canCreateGASTask: Bool {
        kind == .task && !hasReceipt(.gasTask) && !isExecutingAction && gasConfiguration.canUseConnector
    }

    var canCreateCalendarEvent: Bool {
        kind == .event && hasTargetDate && !hasReceipt(.calendarEvent) && !isExecutingAction
    }

    var actionHint: String {
        switch kind {
        case .note:
            return "一般記事只保留在 Inbox，不會建立外部動作。"
        case .task:
            return "待辦可分別送到總務工作台與 Apple Reminders；兩邊都有獨立 Action Receipt，因此不會因重按而重複建立。"
        case .event:
            return hasTargetDate ? "行程可建立為 1 小時的 Apple Calendar 事件。" : "請先指定行程日期與時間。"
        }
    }

    func reanalyzeLocal() {
        guard actionReceipts.isEmpty else { return }
        aiStatusMessage = nil
        apply(localInterpreter.interpret(text: originalText))
    }

    func analyzeWithAI() async {
        guard actionReceipts.isEmpty, !isAIAnalyzing else { return }
        guard aiConfiguration.canUseAI else {
            aiStatusMessage = aiConfiguration.hasAPIKey ? "請先在設定中啟用 AI 分析" : "請先在設定中加入 Gemini API Key"
            return
        }

        isAIAnalyzing = true
        aiStatusMessage = "正在請 AI 理解這筆內容…"
        defer { isAIAnalyzing = false }

        do {
            let result = try await aiInterpreter.interpret(text: originalText)
            apply(result)
            aiStatusMessage = "AI 分析完成；請確認後再儲存或建立動作。"
        } catch {
            aiStatusMessage = "AI 分析失敗，已保留目前結果：\(error.localizedDescription)"
        }
    }

    func keepAsNote() {
        guard actionReceipts.isEmpty else { return }
        kind = .note
        title = originalText
        hasTargetDate = false
        confidence = 1.0
        explanation = "由你指定保留為一般記事"
        source = .manual
        save()
    }

    func save() {
        guard actionReceipts.isEmpty else { return }
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let interpretation = SmartInterpretation(
            kind: kind,
            title: cleanTitle.isEmpty ? originalText : cleanTitle,
            targetDate: hasTargetDate ? targetDate : nil,
            confidence: confidence,
            explanation: explanation,
            source: source,
            taskCategory: gasCategory,
            taskPriority: gasPriority
        )
        store.setInterpretation(id: itemID, interpretation: interpretation)
    }

    func createReminder() async {
        guard canCreateReminder else { return }
        await performAction("正在建立提醒事項…") {
            try await actionService.createReminder(title: finalTitle, dueDate: hasTargetDate ? targetDate : nil)
        }
    }

    func createCalendarEvent() async {
        guard canCreateCalendarEvent else { return }
        await performAction("正在建立行事曆…") {
            try await actionService.createCalendarEvent(title: finalTitle, startDate: targetDate)
        }
    }

    func createGASTask() async {
        guard canCreateGASTask else {
            if !gasConfiguration.canUseConnector {
                actionStatusMessage = "請先到設定完成總務工作台網址、Token 並啟用串接。"
            }
            return
        }
        guard !isCheckingDuplicates else { return }

        isCheckingDuplicates = true
        duplicateCheckMessage = "正在檢查 Inbox 與進行中的總務任務…"
        duplicateCandidates = []
        defer { isCheckingDuplicates = false }

        let localOnly = duplicateGuard.findCandidates(
            currentItemID: itemID,
            title: finalTitle,
            originalText: originalText,
            category: gasCategory,
            inboxItems: store.items,
            remoteTasks: []
        )

        do {
            let digest = try await gasConnector.fetchTaskDigest(limit: 30)
            duplicateCandidates = duplicateGuard.findCandidates(
                currentItemID: itemID,
                title: finalTitle,
                originalText: originalText,
                category: gasCategory,
                inboxItems: store.items,
                remoteTasks: digest.tasks
            )

            if duplicateCandidates.isEmpty {
                duplicateCheckMessage = "未發現明顯重複，準備建立新任務。"
                await createGASTaskWithoutDuplicateCheck()
            } else {
                duplicateCheckMessage = "發現 \(duplicateCandidates.count) 筆可能相同或相關的工作，請先確認。"
                actionStatusMessage = "Duplicate Guard 已暫停建立新任務；請選擇合併或仍建立新任務。"
            }
        } catch {
            duplicateCandidates = localOnly
            if duplicateCandidates.isEmpty {
                duplicateCheckMessage = "無法完成 GAS 遠端重複檢查：\(error.localizedDescription)"
            } else {
                duplicateCheckMessage = "GAS 遠端檢查失敗，但 Inbox 找到 \(duplicateCandidates.count) 筆可能重複。"
            }
            actionStatusMessage = "為避免誤建，DeskPet 沒有自動建立；你仍可選擇『仍建立新任務』。"
        }
    }

    func createGASTaskAnyway() async {
        guard canCreateGASTask else { return }
        duplicateCandidates = []
        duplicateCheckMessage = "你已確認要保留為獨立工作。"
        await createGASTaskWithoutDuplicateCheck()
    }

    func mergeIntoExistingTask(_ candidate: DuplicateCandidate) {
        guard let task = candidate.task, !hasReceipt(.gasTask), !isExecutingAction else { return }
        let receipt = ActionReceipt(
            kind: .gasTask,
            externalIdentifier: task.taskId,
            externalURL: task.detailUrl,
            title: task.name,
            createdAt: Date()
        )
        actionReceipts.append(receipt)
        store.addActionReceipt(id: itemID, receipt: receipt)
        _ = workEventStore.record(
            kind: .taskLinked,
            title: task.name,
            detail: "合併 Inbox 補充：\(originalText)",
            source: .deskPet,
            referenceID: task.taskId,
            category: task.category ?? gasCategory
        )
        duplicateCandidates = []
        duplicateCheckMessage = "已將這筆 Inbox 關聯到既有任務；沒有覆寫 GAS 任務欄位。"
        actionStatusMessage = "已合併至既有任務「\(task.name)」（\(task.taskId)）。"
    }

    func discardAsDuplicateOfInbox(_ candidate: DuplicateCandidate) {
        guard candidate.source == .inbox, candidate.inboxItemID != nil else { return }
        store.delete(id: itemID)
        duplicateCandidates = []
        duplicateCheckMessage = "已保留原 Inbox，刪除這筆重複輸入。"
        actionStatusMessage = "這筆內容已視為 Inbox 重複項目。"
    }

    private func createGASTaskWithoutDuplicateCheck() async {
        await performAction("正在加入總務工作台…") {
            try await gasConnector.createTask(
                clientTaskID: itemID,
                title: finalTitle,
                originalText: originalText,
                category: gasCategory,
                priority: gasPriority,
                dueDate: hasTargetDate ? targetDate : nil
            )
        }
    }

    func clearAnalysis() {
        guard actionReceipts.isEmpty else { return }
        store.setInterpretation(id: itemID, interpretation: nil)
    }

    private var finalTitle: String {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleanTitle.isEmpty ? originalText : cleanTitle
    }

    private func performAction(_ progress: String, operation: () async throws -> ActionReceipt) async {
        guard !isExecutingAction else { return }
        if actionReceipts.isEmpty { save() }
        isExecutingAction = true
        actionStatusMessage = progress
        defer { isExecutingAction = false }

        do {
            let receipt = try await operation()
            if !hasReceipt(receipt.kind) {
                actionReceipts.append(receipt)
                store.addActionReceipt(id: itemID, receipt: receipt)
                recordWorkEvent(for: receipt)
            }
            let suffix = receipt.externalIdentifier.map { "（\($0)）" } ?? ""
            actionStatusMessage = "已建立到 \(receipt.kind.displayName)\(suffix)。"
        } catch {
            actionStatusMessage = "建立失敗：\(error.localizedDescription)"
        }
    }

    private func recordWorkEvent(for receipt: ActionReceipt) {
        let kind: WorkEventKind
        let source: WorkEventSource
        switch receipt.kind {
        case .calendarEvent:
            kind = .calendarCreated
            source = .calendar
        case .reminder:
            kind = .reminderCreated
            source = .reminders
        case .gasTask:
            kind = .taskCreated
            source = .gas
        }

        _ = workEventStore.record(
            kind: kind,
            title: finalTitle,
            detail: originalText,
            source: source,
            referenceID: receipt.externalIdentifier ?? itemID.uuidString,
            category: receipt.kind == .gasTask ? gasCategory : nil,
            timestamp: receipt.createdAt
        )
    }

    private func apply(_ interpretation: SmartInterpretation) {
        guard actionReceipts.isEmpty else { return }
        kind = interpretation.kind
        title = interpretation.title
        hasTargetDate = interpretation.targetDate != nil
        targetDate = interpretation.targetDate ?? Date()
        confidence = interpretation.confidence
        explanation = interpretation.explanation
        source = interpretation.source
        gasCategory = interpretation.taskCategory ?? GASTaskTaxonomy.inferredCategory(from: originalText)
        gasPriority = interpretation.taskPriority ?? GASTaskTaxonomy.inferredPriority(from: originalText)
    }
}
