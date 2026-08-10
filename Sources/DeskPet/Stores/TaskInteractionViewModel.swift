import AppKit
import Combine
import Foundation

@MainActor
final class TaskInteractionViewModel: ObservableObject {
    @Published private(set) var task: GASTaskDigest.Task
    @Published var selectedAction: GASTaskMutationKind?
    @Published var note = ""
    @Published var newDueDate = Date()
    @Published var includeTime = false
    @Published var newDueTime = Date()
    @Published var nextAction = ""
    @Published var waitingTarget = ""
    @Published private(set) var isSubmitting = false
    @Published private(set) var statusMessage = "選擇一個操作後，DeskPet 會先顯示變更內容。"
    @Published private(set) var didSucceed = false

    private let connector: any GASTaskUpdating
    private let gasConfiguration: GASTaskConfigurationStore
    private let workEventStore: WorkEventStore
    private let onUpdated: () async -> Void

    init(
        task: GASTaskDigest.Task,
        connector: any GASTaskUpdating,
        gasConfiguration: GASTaskConfigurationStore,
        workEventStore: WorkEventStore,
        preselectedAction: GASTaskMutationKind? = nil,
        prefilledNote: String? = nil,
        prefilledDueDate: Date? = nil,
        prefilledNextAction: String? = nil,
        onUpdated: @escaping () async -> Void
    ) {
        self.task = task
        self.connector = connector
        self.gasConfiguration = gasConfiguration
        self.workEventStore = workEventStore
        self.onUpdated = onUpdated
        seedDates(from: task)
        nextAction = task.nextAction ?? ""
        waitingTarget = task.waitingFor ?? ""

        if let prefilledDueDate {
            self.newDueDate = prefilledDueDate
            self.newDueTime = prefilledDueDate
            let components = Calendar.current.dateComponents([.hour, .minute], from: prefilledDueDate)
            self.includeTime = (components.hour ?? 0) != 9 || (components.minute ?? 0) != 0
        }

        if let preselectedAction {
            self.selectedAction = preselectedAction
            choose(preselectedAction)
        }

        if let prefilledNote, !prefilledNote.isEmpty {
            self.note = prefilledNote
        }
        if let prefilledNextAction {
            self.nextAction = prefilledNextAction
        }
    }

    var taskActionTitle: String { gasConfiguration.taskActionTitle }

    func choose(_ action: GASTaskMutationKind) {
        selectedAction = action
        didSucceed = false
        switch action {
        case .complete:
            if note.isEmpty { note = "由 DeskPet 確認任務已完成" }
        case .receivedReply:
            if note.isEmpty { note = "已收到回覆，轉回進行中" }
        case .postpone:
            if note.isEmpty { note = "由 DeskPet 調整截止時間" }
        case .updateProgress:
            if note.isEmpty { note = task.progress ?? "" }
        case .followUp:
            if note.isEmpty {
                let target = task.waitingFor?.isEmpty == false ? "（\(task.waitingFor!)）" : ""
                note = "已催辦\(target)"
            }
        case .changeWaiting:
            if note.isEmpty { note = "更新等待對象" }
        case .clearWaiting:
            if note.isEmpty { note = "解除等待，繼續處理" }
        }
        statusMessage = "請確認下方變更預覽；按下確認後才會寫入校務任務系統。"
    }

    var preview: GASTaskMutationPreview? {
        guard let action = selectedAction else { return nil }
        switch action {
        case .complete:
            return GASTaskMutationPreview(
                taskId: task.taskId,
                action: action,
                statusBefore: task.status ?? "",
                statusAfter: "已完成",
                dueDateBefore: task.dueDate ?? "",
                dueDateAfter: nil,
                dueTimeBefore: task.dueTime ?? "",
                dueTimeAfter: nil,
                waitingForBefore: task.waitingFor ?? "",
                waitingForAfter: nil,
                progressBefore: task.progress ?? "",
                progressAfter: note.trimmingCharacters(in: .whitespacesAndNewlines),
                nextActionBefore: task.nextAction ?? "",
                nextActionAfter: nil
            )
        case .receivedReply:
            return GASTaskMutationPreview(
                taskId: task.taskId,
                action: action,
                statusBefore: task.status ?? "",
                statusAfter: "進行中",
                dueDateBefore: task.dueDate ?? "",
                dueDateAfter: nil,
                dueTimeBefore: task.dueTime ?? "",
                dueTimeAfter: nil,
                waitingForBefore: task.waitingFor ?? "",
                waitingForAfter: "",
                progressBefore: task.progress ?? "",
                progressAfter: note.trimmingCharacters(in: .whitespacesAndNewlines),
                nextActionBefore: task.nextAction ?? "",
                nextActionAfter: nil
            )
        case .postpone:
            return GASTaskMutationPreview(
                taskId: task.taskId,
                action: action,
                statusBefore: task.status ?? "",
                statusAfter: nil,
                dueDateBefore: task.dueDate ?? "",
                dueDateAfter: Self.dateFormatter.string(from: newDueDate),
                dueTimeBefore: task.dueTime ?? "",
                dueTimeAfter: includeTime ? Self.timeFormatter.string(from: newDueTime) : "",
                waitingForBefore: task.waitingFor ?? "",
                waitingForAfter: nil,
                progressBefore: task.progress ?? "",
                progressAfter: note.trimmingCharacters(in: .whitespacesAndNewlines),
                nextActionBefore: task.nextAction ?? "",
                nextActionAfter: nil
            )
        case .updateProgress:
            return GASTaskMutationPreview(
                taskId: task.taskId,
                action: action,
                statusBefore: task.status ?? "",
                statusAfter: nil,
                dueDateBefore: task.dueDate ?? "",
                dueDateAfter: nil,
                dueTimeBefore: task.dueTime ?? "",
                dueTimeAfter: nil,
                waitingForBefore: task.waitingFor ?? "",
                waitingForAfter: nil,
                progressBefore: task.progress ?? "",
                progressAfter: note.trimmingCharacters(in: .whitespacesAndNewlines),
                nextActionBefore: task.nextAction ?? "",
                nextActionAfter: nextAction.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        case .followUp:
            return GASTaskMutationPreview(
                taskId: task.taskId,
                action: action,
                statusBefore: task.status ?? "",
                statusAfter: nil,
                dueDateBefore: task.dueDate ?? "",
                dueDateAfter: nil,
                dueTimeBefore: task.dueTime ?? "",
                dueTimeAfter: nil,
                waitingForBefore: task.waitingFor ?? "",
                waitingForAfter: nil,
                progressBefore: task.progress ?? "",
                progressAfter: note.trimmingCharacters(in: .whitespacesAndNewlines),
                nextActionBefore: task.nextAction ?? "",
                nextActionAfter: nil
            )
        case .changeWaiting:
            return GASTaskMutationPreview(
                taskId: task.taskId,
                action: action,
                statusBefore: task.status ?? "",
                statusAfter: "等待他人",
                dueDateBefore: task.dueDate ?? "",
                dueDateAfter: nil,
                dueTimeBefore: task.dueTime ?? "",
                dueTimeAfter: nil,
                waitingForBefore: task.waitingFor ?? "",
                waitingForAfter: waitingTarget.trimmingCharacters(in: .whitespacesAndNewlines),
                progressBefore: task.progress ?? "",
                progressAfter: note.trimmingCharacters(in: .whitespacesAndNewlines),
                nextActionBefore: task.nextAction ?? "",
                nextActionAfter: nil
            )
        case .clearWaiting:
            return GASTaskMutationPreview(
                taskId: task.taskId,
                action: action,
                statusBefore: task.status ?? "",
                statusAfter: "進行中",
                dueDateBefore: task.dueDate ?? "",
                dueDateAfter: nil,
                dueTimeBefore: task.dueTime ?? "",
                dueTimeAfter: nil,
                waitingForBefore: task.waitingFor ?? "",
                waitingForAfter: "",
                progressBefore: task.progress ?? "",
                progressAfter: note.trimmingCharacters(in: .whitespacesAndNewlines),
                nextActionBefore: task.nextAction ?? "",
                nextActionAfter: nil
            )
        }
    }

    func submit() async {
        guard let preview else { return }
        guard !isSubmitting else { return }
        isSubmitting = true
        didSucceed = false
        statusMessage = "正在寫入校務任務系統…"
        defer { isSubmitting = false }

        do {
            let updated = try await connector.updateTask(
                taskId: task.taskId,
                status: preview.statusAfter,
                dueDate: preview.dueDateAfter,
                dueTime: preview.dueTimeAfter,
                nextAction: preview.nextActionAfter,
                waitingFor: preview.waitingForAfter,
                progress: preview.progressAfter?.isEmpty == false ? preview.progressAfter : nil,
                reason: preview.action.title
            )
            task = updated
            recordWorkEvent(for: updated, preview: preview)
            didSucceed = true
            statusMessage = "已更新「\(updated.name)」。"
            await onUpdated()
        } catch {
            statusMessage = "更新失敗：\(error.localizedDescription)"
        }
    }

    private func recordWorkEvent(for updated: GASTaskDigest.Task, preview: GASTaskMutationPreview) {
        let kind: WorkEventKind
        let detail: String
        switch preview.action {
        case .complete:
            kind = .taskCompleted
            detail = preview.progressAfter ?? "任務已完成"
        case .receivedReply:
            kind = .receivedReply
            detail = preview.progressAfter ?? "已收到回覆"
        case .postpone:
            kind = .postponed
            let datePart = preview.dueDateAfter ?? ""
            let timePart = preview.dueTimeAfter ?? ""
            let deadline = [datePart, timePart].filter { !$0.isEmpty }.joined(separator: " ")
            detail = deadline.isEmpty ? (preview.progressAfter ?? "調整截止時間") : "延期至 \(deadline)"
        case .updateProgress:
            kind = .taskUpdated
            let next = preview.nextActionAfter?.isEmpty == false ? "；下一步：\(preview.nextActionAfter!)" : ""
            detail = (preview.progressAfter ?? "更新進度") + next
        case .followUp:
            kind = .taskUpdated
            detail = preview.progressAfter ?? "已催辦"
        case .changeWaiting:
            kind = .taskUpdated
            detail = "等待 \(preview.waitingForAfter ?? "")；\(preview.progressAfter ?? "更新等待對象")"
        case .clearWaiting:
            kind = .taskUpdated
            detail = preview.progressAfter ?? "解除等待"
        }

        _ = workEventStore.record(
            kind: kind,
            title: updated.name,
            detail: detail,
            source: .gas,
            referenceID: updated.taskId,
            category: updated.category
        )
    }

    func openDetailURL() {
        guard let raw = task.detailUrl, let url = URL(string: raw), url.scheme == "https" else { return }
        NSWorkspace.shared.open(url)
    }

    var canOpenDetailURL: Bool {
        guard let raw = task.detailUrl, let url = URL(string: raw) else { return false }
        return url.scheme == "https"
    }

    private func seedDates(from task: GASTaskDigest.Task) {
        if let date = task.dueDate, let parsed = Self.dateFormatter.date(from: date) {
            newDueDate = parsed
        } else {
            newDueDate = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        }
        if let time = task.dueTime, let parsed = Self.timeFormatter.date(from: time) {
            newDueTime = parsed
            includeTime = true
        } else {
            includeTime = false
        }
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = Calendar(identifier: .gregorian)
        f.timeZone = TimeZone(identifier: "Asia/Taipei")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = Calendar(identifier: .gregorian)
        f.timeZone = TimeZone(identifier: "Asia/Taipei")
        f.dateFormat = "HH:mm"
        return f
    }()
}
