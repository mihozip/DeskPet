import Foundation

enum CaptureKind: String, Codable, CaseIterable, Identifiable {
    case note = "記事"
    case task = "待辦"
    case event = "行程"

    var id: String { rawValue }

    var symbolName: String {
        switch self {
        case .note:
            return "note.text"
        case .task:
            return "checkmark.circle"
        case .event:
            return "calendar"
        }
    }
}
