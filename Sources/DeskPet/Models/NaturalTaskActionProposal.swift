import Foundation

enum NaturalTaskActionSource: String, Equatable {
    case local
    case gemini

    var label: String {
        switch self {
        case .local: return "本機規則"
        case .gemini: return "Gemini AI"
        }
    }
}

struct NaturalTaskActionProposal: Identifiable, Equatable {
    let id = UUID()
    let commandText: String
    let task: GASTaskDigest.Task
    let action: GASTaskMutationKind
    let note: String
    let dueDate: Date?
    let nextAction: String?
    let explanation: String
    let confidence: Double
    let source: NaturalTaskActionSource

    init(
        commandText: String,
        task: GASTaskDigest.Task,
        action: GASTaskMutationKind,
        note: String,
        dueDate: Date?,
        nextAction: String? = nil,
        explanation: String,
        confidence: Double,
        source: NaturalTaskActionSource
    ) {
        self.commandText = commandText
        self.task = task
        self.action = action
        self.note = note
        self.dueDate = dueDate
        self.nextAction = nextAction
        self.explanation = explanation
        self.confidence = confidence
        self.source = source
    }

    var includeTime: Bool {
        guard let dueDate else { return false }
        let components = Calendar.current.dateComponents([.hour, .minute], from: dueDate)
        return (components.hour ?? 0) != 9 || (components.minute ?? 0) != 0
    }
}

struct NaturalTaskActionAmbiguity: Equatable {
    let message: String
    let candidates: [GASTaskDigest.Task]
    let action: GASTaskMutationKind?
    let note: String
    let dueDate: Date?
    let nextAction: String?
    let confidence: Double
    let source: NaturalTaskActionSource
}
