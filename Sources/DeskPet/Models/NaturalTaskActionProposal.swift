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
    let explanation: String
    let confidence: Double
    let source: NaturalTaskActionSource

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
    let confidence: Double
    let source: NaturalTaskActionSource
}
