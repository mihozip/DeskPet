import Combine
import EventKit
import Foundation

@MainActor
final class CalendarActionService: ObservableObject {
    enum PermissionState: Equatable {
        case notDetermined
        case restricted
        case denied
        case writeOnly
        case fullAccess
        case legacyAuthorized
        case unknown

        var hasFullAccess: Bool {
            self == .fullAccess || self == .legacyAuthorized
        }

        var hasCalendarWriteAccess: Bool {
            hasFullAccess || self == .writeOnly
        }

        var needsSystemSettings: Bool {
            self == .denied
        }
    }

    enum ActionError: LocalizedError {
        case calendarPermissionDenied
        case remindersPermissionDenied
        case noDefaultCalendar
        case noDefaultReminderList
        case missingEventDate

        var errorDescription: String? {
            switch self {
            case .calendarPermissionDenied:
                return "DeskPet 尚未取得行事曆權限"
            case .remindersPermissionDenied:
                return "DeskPet 尚未取得提醒事項權限"
            case .noDefaultCalendar:
                return "找不到可新增行程的預設行事曆"
            case .noDefaultReminderList:
                return "找不到可新增提醒事項的預設清單"
            case .missingEventDate:
                return "行程必須先確認日期與時間"
            }
        }
    }

    @Published private(set) var calendarPermissionState: PermissionState = .unknown
    @Published private(set) var remindersPermissionState: PermissionState = .unknown
    @Published private(set) var calendarErrorText: String?
    @Published private(set) var remindersErrorText: String?

    var calendarStatusText: String {
        statusText(for: calendarPermissionState, entityType: .event)
    }

    var remindersStatusText: String {
        statusText(for: remindersPermissionState, entityType: .reminder)
    }

    // Keep Calendar and Reminders on physically separate stores. Authorization
    // state itself always comes from EKEventStore.authorizationStatus(for:).
    private let calendarStore = EKEventStore()
    private let remindersStore = EKEventStore()

    init() {
        refreshAuthorizationStatus()
    }

    func refreshAuthorizationStatus() {
        refreshCalendarAuthorizationStatus()
        refreshRemindersAuthorizationStatus()
    }

    func refreshCalendarAuthorizationStatus() {
        calendarPermissionState = permissionState(
            from: EKEventStore.authorizationStatus(for: .event),
            entityType: .event
        )
    }

    func refreshRemindersAuthorizationStatus() {
        remindersPermissionState = permissionState(
            from: EKEventStore.authorizationStatus(for: .reminder),
            entityType: .reminder
        )
    }

    /// Calendar Intelligence reads existing events, so the Settings permission
    /// request always asks for full event access. A previously granted write-only
    /// permission may still create events, but it is not enough for queries.
    func requestCalendarAccess() async -> Bool {
        calendarErrorText = nil
        refreshCalendarAuthorizationStatus()

        switch calendarPermissionState {
        case .fullAccess, .legacyAuthorized:
            return true
        case .denied:
            calendarErrorText = "行事曆權限已被拒絕。macOS 不會再次顯示授權視窗，請到「系統設定 → 隱私權與安全性 → 行事曆」開啟 DeskPet。"
            return false
        case .restricted:
            calendarErrorText = "此 Mac 目前限制行事曆存取，DeskPet 無法自行解除。"
            return false
        case .notDetermined, .writeOnly, .unknown:
            break
        }

        do {
            let granted: Bool
            if #available(macOS 14.0, *) {
                granted = try await calendarStore.requestFullAccessToEvents()
            } else {
                granted = try await requestLegacyAccess(to: .event, store: calendarStore)
            }

            if granted {
                calendarStore.reset()
                await waitForSystemAuthorizationState(for: .event)
            } else {
                refreshCalendarAuthorizationStatus()
            }

            if calendarPermissionState.hasFullAccess {
                return true
            }

            if granted {
                calendarErrorText = "macOS 已完成授權流程，但目前尚未回報完整存取。請按「重新檢查」；若仍未更新，請到系統設定確認行事曆權限。"
            }
            return false
        } catch {
            refreshCalendarAuthorizationStatus()
            calendarErrorText = "行事曆授權失敗：\(error.localizedDescription)"
            return false
        }
    }

    func requestRemindersAccess() async -> Bool {
        remindersErrorText = nil
        refreshRemindersAuthorizationStatus()

        switch remindersPermissionState {
        case .fullAccess, .legacyAuthorized:
            return true
        case .denied:
            remindersErrorText = "提醒事項權限已被拒絕。macOS 不會再次顯示授權視窗，請到「系統設定 → 隱私權與安全性 → 提醒事項」開啟 DeskPet。"
            return false
        case .restricted:
            remindersErrorText = "此 Mac 目前限制提醒事項存取，DeskPet 無法自行解除。"
            return false
        case .notDetermined, .writeOnly, .unknown:
            break
        }

        do {
            let granted: Bool
            if #available(macOS 14.0, *) {
                granted = try await remindersStore.requestFullAccessToReminders()
            } else {
                granted = try await requestLegacyAccess(to: .reminder, store: remindersStore)
            }

            if granted {
                remindersStore.reset()
                await waitForSystemAuthorizationState(for: .reminder)
            } else {
                refreshRemindersAuthorizationStatus()
            }

            if remindersPermissionState.hasFullAccess {
                return true
            }

            if granted {
                remindersErrorText = "macOS 已完成授權流程，但目前尚未回報提醒事項完整存取。請按「重新檢查」；若仍未更新，請到系統設定確認權限。"
            }
            return false
        } catch {
            refreshRemindersAuthorizationStatus()
            remindersErrorText = "提醒事項授權失敗：\(error.localizedDescription)"
            return false
        }
    }

    func createCalendarEvent(title: String, startDate: Date, duration: TimeInterval = 3600) async throws -> ActionReceipt {
        guard await ensureCalendarWriteAccess() else {
            throw ActionError.calendarPermissionDenied
        }
        guard let calendar = calendarStore.defaultCalendarForNewEvents else {
            throw ActionError.noDefaultCalendar
        }

        let event = EKEvent(eventStore: calendarStore)
        event.title = title
        event.startDate = startDate
        event.endDate = startDate.addingTimeInterval(duration)
        event.calendar = calendar
        try calendarStore.save(event, span: .thisEvent, commit: true)

        return ActionReceipt(
            kind: .calendarEvent,
            externalIdentifier: event.eventIdentifier,
            title: title,
            createdAt: Date()
        )
    }

    func createReminder(title: String, dueDate: Date?) async throws -> ActionReceipt {
        guard await ensureRemindersAccess() else {
            throw ActionError.remindersPermissionDenied
        }
        guard let calendar = remindersStore.defaultCalendarForNewReminders() else {
            throw ActionError.noDefaultReminderList
        }

        let reminder = EKReminder(eventStore: remindersStore)
        reminder.title = title
        reminder.calendar = calendar

        if let dueDate {
            var components = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: dueDate
            )
            components.calendar = Calendar.current
            components.timeZone = TimeZone.current
            reminder.dueDateComponents = components
        }

        try remindersStore.save(reminder, commit: true)

        return ActionReceipt(
            kind: .reminder,
            externalIdentifier: reminder.calendarItemIdentifier,
            title: title,
            createdAt: Date()
        )
    }

    private func ensureCalendarWriteAccess() async -> Bool {
        refreshCalendarAuthorizationStatus()
        if calendarPermissionState.hasCalendarWriteAccess { return true }
        if calendarPermissionState == .notDetermined {
            return await requestCalendarAccess()
        }
        return false
    }

    private func ensureRemindersAccess() async -> Bool {
        refreshRemindersAuthorizationStatus()
        if remindersPermissionState.hasFullAccess { return true }
        if remindersPermissionState == .notDetermined {
            return await requestRemindersAccess()
        }
        return false
    }

    /// The authorization completion and TCC's visible status can settle on
    /// slightly different turns of the run loop. Never invent an "authorized"
    /// UI state from the completion Boolean; poll the real EventKit status for a
    /// short bounded period and publish only what macOS actually reports.
    private func waitForSystemAuthorizationState(for entityType: EKEntityType) async {
        for _ in 0..<20 {
            let state = permissionState(
                from: EKEventStore.authorizationStatus(for: entityType),
                entityType: entityType
            )

            if entityType == .event {
                calendarPermissionState = state
                if state.hasFullAccess || state == .denied || state == .restricted { return }
            } else {
                remindersPermissionState = state
                if state.hasFullAccess || state == .denied || state == .restricted { return }
            }

            try? await Task.sleep(nanoseconds: 100_000_000)
        }

        if entityType == .event {
            refreshCalendarAuthorizationStatus()
        } else {
            refreshRemindersAuthorizationStatus()
        }
    }

    private func permissionState(from status: EKAuthorizationStatus, entityType: EKEntityType) -> PermissionState {
        if #available(macOS 14.0, *) {
            switch status {
            case .notDetermined:
                return .notDetermined
            case .restricted:
                return .restricted
            case .denied:
                return .denied
            case .fullAccess:
                return .fullAccess
            case .writeOnly:
                return entityType == .event ? .writeOnly : .unknown
            case .authorized:
                // Kept only as a defensive compatibility mapping. New SDKs use
                // fullAccess/writeOnly on macOS 14+.
                return .legacyAuthorized
            @unknown default:
                return .unknown
            }
        }

        switch status {
        case .notDetermined:
            return .notDetermined
        case .restricted:
            return .restricted
        case .denied:
            return .denied
        case .authorized:
            return .legacyAuthorized
        default:
            return .unknown
        }
    }

    private func statusText(for state: PermissionState, entityType: EKEntityType) -> String {
        switch state {
        case .notDetermined:
            return "尚未授權"
        case .restricted:
            return "受系統限制"
        case .denied:
            return "已拒絕（需至系統設定開啟）"
        case .writeOnly:
            return entityType == .event ? "僅可新增行程，無法查詢既有行程" : "權限狀態異常"
        case .fullAccess:
            return "完整存取已授權"
        case .legacyAuthorized:
            return "已授權"
        case .unknown:
            return "權限狀態未知，請重新檢查"
        }
    }

    private func requestLegacyAccess(to entityType: EKEntityType, store: EKEventStore) async throws -> Bool {
        try await withCheckedThrowingContinuation { continuation in
            store.requestAccess(to: entityType) { granted, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: granted)
                }
            }
        }
    }
}
