import AppKit
import Foundation

final class CaptureStore: ObservableObject {
    @Published private(set) var items: [CaptureItem] = []

    private let fileManager: FileManager
    private let fileURL: URL
    private let workEventStore: WorkEventStore?

    init(fileManager: FileManager = .default, workEventStore: WorkEventStore? = nil) {
        self.fileManager = fileManager
        self.workEventStore = workEventStore

        let supportDirectory = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!

        let appDirectory = supportDirectory.appendingPathComponent(
            "DeskPet",
            isDirectory: true
        )

        try? fileManager.createDirectory(
            at: appDirectory,
            withIntermediateDirectories: true
        )

        self.fileURL = appDirectory.appendingPathComponent("inbox.json")
        load()
    }

    var inboxCount: Int {
        items.filter { $0.status == .inbox }.count
    }

    @discardableResult
    func add(text: String) -> CaptureItem? {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return nil }

        let item = CaptureItem(text: cleaned)
        items.insert(item, at: 0)
        save()
        _ = workEventStore?.record(
            kind: .noteCreated,
            title: cleaned,
            detail: "快速記事",
            source: .deskPet,
            referenceID: item.id.uuidString
        )
        return item
    }

    func item(id: UUID) -> CaptureItem? {
        items.first { $0.id == id }
    }

    func toggleDone(id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        switch items[index].status {
        case .inbox:
            items[index].status = .done
        case .done:
            items[index].status = .inbox
        case .converted:
            return
        }
        save()
    }

    func setInterpretation(id: UUID, interpretation: SmartInterpretation?) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].interpretation = interpretation
        save()
    }

    func addActionReceipt(id: UUID, receipt: ActionReceipt) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        guard !items[index].actionReceipts.contains(where: { $0.kind == receipt.kind }) else { return }
        items[index].actionReceipts.append(receipt)

        if receipt.kind == .gasTask, let taskID = receipt.externalIdentifier, !taskID.isEmpty {
            items[index].linkedGASTaskID = taskID
            items[index].linkedGASTaskTitle = receipt.title
            items[index].linkedGASTaskURL = receipt.externalURL
            items[index].convertedAt = receipt.createdAt
            items[index].status = .converted
        }
        save()
    }

    func hasActionReceipt(id: UUID, kind: DeskPetActionKind) -> Bool {
        items.first(where: { $0.id == id })?.actionReceipts.contains(where: { $0.kind == kind }) == true
    }

    func delete(id: UUID) {
        items.removeAll { $0.id == id }
        save()
    }

    func deleteCompleted() {
        items.removeAll { $0.status == .done }
        save()
    }

    func revealInboxFile() {
        ensureFileExists()
        NSWorkspace.shared.activateFileViewerSelecting([fileURL])
    }

    private func load() {
        guard fileManager.fileExists(atPath: fileURL.path) else { return }

        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            items = try decoder.decode([CaptureItem].self, from: data)
        } catch {
            NSLog("DeskPet: failed to load inbox: %@", error.localizedDescription)
        }
    }

    private func save() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(items)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            NSLog("DeskPet: failed to save inbox: %@", error.localizedDescription)
        }
    }

    private func ensureFileExists() {
        guard !fileManager.fileExists(atPath: fileURL.path) else { return }
        save()
    }
}
