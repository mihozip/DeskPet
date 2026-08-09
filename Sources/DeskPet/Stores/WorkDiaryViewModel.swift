import AppKit
import Combine
import Foundation

@MainActor
final class WorkDiaryViewModel: ObservableObject {
    @Published var selectedDate: Date = Date()
    @Published var manualNote: String = ""
    @Published private(set) var statusMessage: String?

    let store: WorkEventStore
    private let calendar: Calendar
    private var cancellables: Set<AnyCancellable> = []

    init(store: WorkEventStore, calendar: Calendar = .current) {
        self.store = store
        self.calendar = calendar
        store.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    var dayEvents: [WorkEvent] {
        store.events(on: selectedDate).sorted { $0.timestamp > $1.timestamp }
    }

    var completedEvents: [WorkEvent] { events(in: .completed) }
    var progressEvents: [WorkEvent] { events(in: .progress) }
    var noteEvents: [WorkEvent] { events(in: .notes) }

    var isToday: Bool { calendar.isDateInToday(selectedDate) }

    func previousDay() {
        selectedDate = calendar.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
        statusMessage = nil
    }

    func nextDay() {
        selectedDate = calendar.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
        statusMessage = nil
    }

    func goToday() {
        selectedDate = Date()
        statusMessage = nil
    }

    func addManualNote() {
        let cleaned = manualNote.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else {
            statusMessage = "請先輸入要補充的工作紀錄。"
            return
        }

        let timestamp: Date
        if calendar.isDateInToday(selectedDate) {
            timestamp = Date()
        } else {
            var comps = calendar.dateComponents([.year, .month, .day], from: selectedDate)
            let now = calendar.dateComponents([.hour, .minute, .second], from: Date())
            comps.hour = now.hour
            comps.minute = now.minute
            comps.second = now.second
            timestamp = calendar.date(from: comps) ?? selectedDate
        }

        _ = store.record(
            kind: .manualDiaryNote,
            title: cleaned,
            detail: "手動加入工作日誌",
            source: .manual,
            timestamp: timestamp
        )
        manualNote = ""
        statusMessage = "已加入工作日誌。"
    }

    func deleteManualNote(id: UUID) {
        store.deleteManualEvent(id: id)
        statusMessage = "已刪除手動補充紀錄。"
    }

    func copyDiaryToPasteboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(formattedDiaryText(), forType: .string)
        statusMessage = "已複製當日工作日誌。"
    }

    func revealEventsFile() {
        store.revealEventsFile()
    }

    func formattedDiaryText() -> String {
        var lines: [String] = []
        lines.append("\(Self.dayFormatter.string(from: selectedDate)) 工作日誌")

        appendSection(.completed, events: completedEvents, to: &lines)
        appendSection(.progress, events: progressEvents, to: &lines)
        appendSection(.notes, events: noteEvents, to: &lines)

        if dayEvents.isEmpty {
            lines.append("")
            lines.append("今天尚無工作紀錄。")
        }
        return lines.joined(separator: "\n")
    }

    private func events(in section: WorkDiarySection) -> [WorkEvent] {
        store.events(on: selectedDate)
            .filter { $0.kind.diarySection == section }
            .sorted { $0.timestamp < $1.timestamp }
    }

    private func appendSection(_ section: WorkDiarySection, events: [WorkEvent], to lines: inout [String]) {
        guard !events.isEmpty else { return }
        lines.append("")
        lines.append("【\(section.title)】")
        for event in events {
            var line = "- \(event.title)"
            if let detail = event.detail, detail != event.title, !detail.isEmpty {
                line += "（\(detail)）"
            }
            lines.append(line)
        }
    }

    static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_TW")
        formatter.dateFormat = "yyyy/MM/dd（EEE）"
        return formatter
    }()

    static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_TW")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
}
