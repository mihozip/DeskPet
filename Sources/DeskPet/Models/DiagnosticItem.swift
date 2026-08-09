import Foundation

struct DiagnosticItem: Identifiable {
    enum Level {
        case ok
        case warning
        case error
    }

    let id: String
    let title: String
    let detail: String
    let level: Level
}
