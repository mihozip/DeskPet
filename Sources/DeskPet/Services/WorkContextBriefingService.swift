import Combine
import Foundation

@MainActor
final class WorkContextBriefingService: ObservableObject {
    @Published private(set) var announcement: String?
    @Published private(set) var latestSnapshot: WorkContextSnapshot?

    private enum Key {
        static let lastBriefingDay = "DeskPet.contextBriefing.lastDay"
        static let lastBriefingAt = "DeskPet.contextBriefing.lastAt"
        static let lastSignature = "DeskPet.contextBriefing.lastSignature"
        static let lastUpcomingEventID = "DeskPet.contextBriefing.lastUpcomingEventID"
    }

    private let monitor: GASTaskAmbientMonitor
    private let captureStore: CaptureStore
    private let workEventStore: WorkEventStore
    private let snoozeStore: SnoozeStore
    private let calendarQueryService: CalendarQueryService
    private let defaults: UserDefaults
    private let engine: WorkContextEngine
    private var calendar: Calendar
    private var calendarEvents: [CalendarEventSummary] = []
    private var cancellables = Set<AnyCancellable>()
    private var timer: Timer?
    private var announcementWorkItem: DispatchWorkItem?
    private var started = false

    init(
        monitor: GASTaskAmbientMonitor,
        captureStore: CaptureStore,
        workEventStore: WorkEventStore,
        snoozeStore: SnoozeStore,
        calendarQueryService: CalendarQueryService,
        defaults: UserDefaults = .standard,
        timeZone: TimeZone = TimeZone(identifier: "Asia/Taipei")!
    ) {
        self.monitor = monitor
        self.captureStore = captureStore
        self.workEventStore = workEventStore
        self.snoozeStore = snoozeStore
        self.calendarQueryService = calendarQueryService
        self.defaults = defaults
        engine = WorkContextEngine(timeZone: timeZone)

        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "zh_TW")
        calendar.timeZone = timeZone
        self.calendar = calendar
    }

    func start() {
        guard !started else { return }
        started = true

        Publishers.CombineLatest4(
            monitor.$digest,
            captureStore.$items,
            workEventStore.$events,
            snoozeStore.$snoozedUntil
        )
        .dropFirst()
        .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
        .sink { [weak self] _, _, _, _ in
            self?.evaluate(reason: .sourceChanged)
        }
        .store(in: &cancellables)

        timer = Timer.scheduledTimer(withTimeInterval: 15 * 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.refreshCalendarAndEvaluate(reason: .timer)
            }
        }
        timer?.tolerance = 60

        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            await self?.refreshCalendarAndEvaluate(reason: .startup)
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        announcementWorkItem?.cancel()
        cancellables.removeAll()
        started = false
    }

    func dismissAnnouncement() {
        announcementWorkItem?.cancel()
        announcement = nil
    }

    func refreshNow() async {
        await refreshCalendarAndEvaluate(reason: .manual)
    }

    private enum EvaluationReason {
        case startup
        case sourceChanged
        case timer
        case manual
    }

    private func refreshCalendarAndEvaluate(reason: EvaluationReason) async {
        let now = Date()
        let start = calendar.startOfDay(for: now)
        guard let end = calendar.date(byAdding: .day, value: 2, to: start) else {
            evaluate(reason: reason, now: now)
            return
        }

        do {
            calendarEvents = try await calendarQueryService.events(in: DateInterval(start: start, end: end))
        } catch {
            calendarEvents = []
        }
        evaluate(reason: reason, now: now)
    }

    private func evaluate(reason: EvaluationReason, now: Date = Date()) {
        snoozeStore.purgeExpired(now: now)

        let snapshot = engine.snapshot(
            tasks: monitor.digest?.tasks ?? [],
            inboxItems: captureStore.items,
            workEvents: workEventStore.events,
            calendarEvents: calendarEvents,
            snoozedUntil: snoozeStore.snoozedUntil,
            now: now
        )
        latestSnapshot = snapshot

        guard hasUsefulContext(snapshot) else { return }

        let today = dayKey(now)
        let lastDay = defaults.string(forKey: Key.lastBriefingDay)
        let lastAt = Date(timeIntervalSince1970: defaults.double(forKey: Key.lastBriefingAt))
        let lastSignature = defaults.string(forKey: Key.lastSignature)
        let signature = briefingSignature(snapshot)

        if lastDay != today {
            defaults.removeObject(forKey: Key.lastUpcomingEventID)
            publish(snapshot.headline, signature: signature, now: now, day: today)
            return
        }

        if let upcoming = snapshot.nextEvent,
           !upcoming.isAllDay,
           upcoming.startDate > now,
           upcoming.startDate.timeIntervalSince(now) <= 60 * 60,
           upcoming.startDate.timeIntervalSince(now) >= 10 * 60,
           defaults.string(forKey: Key.lastUpcomingEventID) != upcoming.id {
            defaults.set(upcoming.id, forKey: Key.lastUpcomingEventID)
            publish(snapshot.headline, signature: signature, now: now, day: today)
            return
        }

        let completedSinceLastBriefing = workEventStore.events.contains {
            $0.kind == .taskCompleted && $0.timestamp > lastAt && $0.timestamp <= now
        }

        if signature != lastSignature {
            let cooldown: TimeInterval = completedSinceLastBriefing ? 0 : 30 * 60
            if now.timeIntervalSince(lastAt) >= cooldown {
                publish(snapshot.headline, signature: signature, now: now, day: today)
            }
        } else if reason == .manual {
            publish(snapshot.headline, signature: signature, now: now, day: today)
        }
    }

    private func publish(_ text: String, signature: String, now: Date, day: String) {
        announcementWorkItem?.cancel()
        announcement = text
        defaults.set(day, forKey: Key.lastBriefingDay)
        defaults.set(now.timeIntervalSince1970, forKey: Key.lastBriefingAt)
        defaults.set(signature, forKey: Key.lastSignature)

        let workItem = DispatchWorkItem { [weak self] in
            self?.announcement = nil
        }
        announcementWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 12, execute: workItem)
    }

    private func hasUsefulContext(_ snapshot: WorkContextSnapshot) -> Bool {
        !snapshot.nowItems.isEmpty || !snapshot.nextItems.isEmpty || !snapshot.laterItems.isEmpty
    }

    private func briefingSignature(_ snapshot: WorkContextSnapshot) -> String {
        if let first = snapshot.nowItems.first { return first.id }
        if let next = snapshot.nextItems.first { return next.id }
        return snapshot.headline
    }

    private func dayKey(_ date: Date) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
    }
}
