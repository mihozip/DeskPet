import Combine
import Foundation

@MainActor
final class SnoozeStore: ObservableObject {
    struct Record: Codable, Equatable {
        let taskID: String
        let snoozedUntil: Date
    }

    @Published private(set) var snoozedUntil: [String: Date] = [:]

    private let defaults: UserDefaults
    private let key: String

    init(defaults: UserDefaults = .standard, key: String = "DeskPet.dailyWork.snooze.v1") {
        self.defaults = defaults
        self.key = key
        load()
    }

    func snooze(taskID: String, until: Date) {
        let id = taskID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !id.isEmpty, until.timeIntervalSince1970.isFinite else { return }
        snoozedUntil[id] = until
        save()
    }

    func wake(taskID: String) {
        snoozedUntil.removeValue(forKey: taskID)
        save()
    }

    func purgeExpired(now: Date = Date()) {
        let before = snoozedUntil.count
        snoozedUntil = snoozedUntil.filter { $0.value > now }
        if snoozedUntil.count != before { save() }
    }

    func isSnoozed(taskID: String, now: Date = Date()) -> Bool {
        guard let until = snoozedUntil[taskID] else { return false }
        return until > now
    }

    private func load() {
        guard let data = defaults.data(forKey: key),
              let records = try? JSONDecoder().decode([Record].self, from: data) else {
            snoozedUntil = [:]
            return
        }
        snoozedUntil = Dictionary(uniqueKeysWithValues: records.compactMap { record in
            let id = record.taskID.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !id.isEmpty, record.snoozedUntil.timeIntervalSince1970.isFinite else { return nil }
            return (id, record.snoozedUntil)
        })
    }

    private func save() {
        let records = snoozedUntil.map { Record(taskID: $0.key, snoozedUntil: $0.value) }.sorted { $0.taskID < $1.taskID }
        if let data = try? JSONEncoder().encode(records) { defaults.set(data, forKey: key) }
    }
}
