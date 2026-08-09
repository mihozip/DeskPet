import Foundation

enum InterpretationSource: String, Codable, Equatable {
    case local
    case gemini
    case openAI // 保留舊值，讓 0.3.1 已儲存的 Inbox 可以繼續解碼
    case manual
}

struct SmartInterpretation: Codable, Equatable {
    var kind: CaptureKind
    var title: String
    var targetDate: Date?
    var confidence: Double
    var explanation: String
    var source: InterpretationSource? = nil
    var taskCategory: String? = nil
    var taskPriority: String? = nil
}
