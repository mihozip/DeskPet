import Combine
import Foundation

@MainActor
final class GASTaskAmbientMonitor: ObservableObject {
    @Published private(set) var digest: GASTaskDigest?
    @Published private(set) var announcement: String?
    @Published private(set) var statusMessage = "尚未同步校務任務系統"
    @Published private(set) var lastUpdated: Date?
    @Published private(set) var isRefreshing = false

    private let configuration: GASTaskConfigurationStore
    private let connector: GASTaskConnector
    private var timer: Timer?
    private var announcementWorkItem: DispatchWorkItem?
    private var previousSummary: GASTaskDigest.Summary?
    private var hasCompletedFirstSync = false

    init(configuration: GASTaskConfigurationStore, connector: GASTaskConnector) {
        self.configuration = configuration
        self.connector = connector
    }

    var isMonitoring: Bool {
        configuration.isEnabled && configuration.ambientEnabled && configuration.canUseConnector
    }

    var intervalMinutes: Int { configuration.ambientIntervalMinutes }
    var administrativeTitle: String { configuration.administrativeTitle }

    func start() {
        reconfigure()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        announcementWorkItem?.cancel()
    }

    func reconfigure() {
        timer?.invalidate()
        timer = nil

        guard isMonitoring else {
            statusMessage = configuration.isEnabled
                ? "主動摘要已關閉或尚未設定 API Token"
                : "校務任務系統串接未啟用"
            return
        }

        let interval = TimeInterval(configuration.ambientIntervalMinutes * 60)
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.refresh(manual: false)
            }
        }
        timer?.tolerance = min(60, interval * 0.1)

        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            await self?.refresh(manual: false)
        }
    }

    func refresh(manual: Bool) async {
        guard !isRefreshing else { return }
        guard configuration.canUseConnector else {
            statusMessage = "校務任務系統尚未完成連線設定"
            return
        }

        isRefreshing = true
        statusMessage = "正在同步校務任務系統…"
        defer { isRefreshing = false }

        do {
            let newDigest = try await connector.fetchTaskDigest(limit: 12)
            let oldSummary = previousSummary
            digest = newDigest
            previousSummary = newDigest.summary
            lastUpdated = Date()
            statusMessage = Self.statusText(for: newDigest)

            let shouldAnnounce: Bool
            if manual {
                shouldAnnounce = true
            } else if !hasCompletedFirstSync {
                shouldAnnounce = Self.hasAttentionItems(newDigest.summary)
            } else {
                shouldAnnounce = Self.hasMeaningfulChange(from: oldSummary, to: newDigest.summary)
            }
            hasCompletedFirstSync = true

            if shouldAnnounce {
                showAnnouncement(Self.announcementText(for: newDigest, administrativeTitle: configuration.administrativeTitle))
            }
        } catch {
            statusMessage = "同步失敗：\(error.localizedDescription)"
        }
    }

    func dismissAnnouncement() {
        announcementWorkItem?.cancel()
        announcement = nil
    }

    private func showAnnouncement(_ text: String) {
        announcementWorkItem?.cancel()
        announcement = text

        let workItem = DispatchWorkItem { [weak self] in
            self?.announcement = nil
        }
        announcementWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 9, execute: workItem)
    }

    private static func hasAttentionItems(_ summary: GASTaskDigest.Summary) -> Bool {
        summary.overdue > 0 || summary.dueToday > 0 || summary.urgent > 0 || summary.waiting > 0
    }

    private static func hasMeaningfulChange(
        from old: GASTaskDigest.Summary?,
        to new: GASTaskDigest.Summary
    ) -> Bool {
        guard let old else { return hasAttentionItems(new) }
        return old.overdue != new.overdue
            || old.dueToday != new.dueToday
            || old.urgent != new.urgent
            || old.waiting != new.waiting
    }

    private static func statusText(for digest: GASTaskDigest) -> String {
        let s = digest.summary
        return "已同步：進行中 \(s.active)｜今日 \(s.dueToday)｜逾期 \(s.overdue)｜高優先 \(s.urgent)｜等待 \(s.waiting)"
    }

    private static func announcementText(for digest: GASTaskDigest, administrativeTitle: String) -> String {
        let s = digest.summary
        var parts: [String] = []
        if s.overdue > 0 { parts.append("\(s.overdue) 件逾期") }
        if s.dueToday > 0 { parts.append("\(s.dueToday) 件今天到期") }
        if s.urgent > 0 { parts.append("\(s.urgent) 件高優先") }
        if s.waiting > 0 { parts.append("\(s.waiting) 件等待中") }

        if parts.isEmpty {
            return s.active == 0 ? "目前沒有進行中的\(administrativeTitle)任務。" : "目前有 \(s.active) 件進行中任務，沒有急迫項目。"
        }

        if let first = digest.tasks.first {
            return "校務任務系統：\(parts.joined(separator: "、"))。先看「\(first.name)」。"
        }
        return "校務任務系統：\(parts.joined(separator: "、"))。"
    }
}
