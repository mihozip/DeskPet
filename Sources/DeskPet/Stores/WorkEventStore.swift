import AppKit
import Combine
import Foundation

final class WorkEventStore: ObservableObject {
    @Published private(set) var events: [WorkEvent] = []

    private let fileManager: FileManager
    private let fileURL: URL
    private let calendar: Calendar

    init(fileManager: FileManager = .default, calendar: Calendar = .current, storageDirectory: URL? = nil) {
        self.fileManager = fileManager
        self.calendar = calendar

        let supportDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDirectory = storageDirectory ?? supportDirectory.appendingPathComponent("DeskPet", isDirectory: true)
        try? fileManager.createDirectory(at: appDirectory, withIntermediateDirectories: true)
        fileURL = appDirectory.appendingPathComponent("work-events.json")
        load()
    }

    @discardableResult
    func record(
        kind: WorkEventKind,
        title: String,
        detail: String? = nil,
        source: WorkEventSource = .deskPet,
        referenceID: String? = nil,
        category: String? = nil,
        timestamp: Date = Date()
    ) -> WorkEvent? {
        let cleanedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedTitle.isEmpty else { return nil }

        let cleanedDetail = detail?.trimmingCharacters(in: .whitespacesAndNewlines)
        let event = WorkEvent(
            timestamp: timestamp,
            kind: kind,
            title: cleanedTitle,
            detail: cleanedDetail?.isEmpty == false ? cleanedDetail : nil,
            source: source,
            referenceID: referenceID,
            category: category
        )
        events.append(event)
        events.sort { $0.timestamp < $1.timestamp }
        save()
        return event
    }

    func events(on date: Date) -> [WorkEvent] {
        events.filter { calendar.isDate($0.timestamp, inSameDayAs: date) }
    }

    func deleteManualEvent(id: UUID) {
        guard let event = events.first(where: { $0.id == id }), event.kind == .manualDiaryNote else { return }
        events.removeAll { $0.id == id }
        save()
    }

    func revealEventsFile() {
        ensureFileExists()
        NSWorkspace.shared.activateFileViewerSelecting([fileURL])
    }

    private func load() {
        guard fileManager.fileExists(atPath: fileURL.path) else { return }
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            events = try decoder.decode([WorkEvent].self, from: data).sorted { $0.timestamp < $1.timestamp }
        } catch {
            NSLog("DeskPet: failed to load work events: %@", error.localizedDescription)
        }
    }

    private func save() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(events)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            NSLog("DeskPet: failed to save work events: %@", error.localizedDescription)
        }
    }

    private func ensureFileExists() {
        guard !fileManager.fileExists(atPath: fileURL.path) else { return }
        save()
    }
}
