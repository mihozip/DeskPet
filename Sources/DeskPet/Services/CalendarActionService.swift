import Combine
import EventKit
import Foundation

@MainActor
final class CalendarActionService: ObservableObject {
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

    @Published private(set) var calendarStatusText = "尚未檢查"
    @Published private(set) var remindersStatusText = "尚未檢查"

    private let eventStore = EKEventStore()

    init() {
        refreshAuthorizationStatus()
    }

    func refreshAuthorizationStatus() {
        calendarStatusText = statusText(for: EKEventStore.authorizationStatus(for: .event), entityType: .event)
        remindersStatusText = statusText(for: EKEventStore.authorizationStatus(for: .reminder), entityType: .reminder)
    }

    func requestCalendarAccess() async -> Bool {
        do {
            let granted: Bool
            if #available(macOS 14.0, *) {
                granted = try await eventStore.requestWriteOnlyAccessToEvents()
            } else {
                granted = try await requestLegacyAccess(to: .event)
            }
            refreshAuthorizationStatus()
            return granted
        } catch {
            calendarStatusText = "授權失敗：\(error.localizedDescription)"
            return false
        }
    }

    func requestRemindersAccess() async -> Bool {
        do {
            let granted: Bool
            if #available(macOS 14.0, *) {
                granted = try await eventStore.requestFullAccessToReminders()
            } else {
                granted = try await requestLegacyAccess(to: .reminder)
            }
            refreshAuthorizationStatus()
            return granted
        } catch {
            remindersStatusText = "授權失敗：\(error.localizedDescription)"
            return false
        }
    }

    func createCalendarEvent(title: String, startDate: Date, duration: TimeInterval = 3600) async throws -> ActionReceipt {
        guard await ensureCalendarAccess() else {
            throw ActionError.calendarPermissionDenied
        }
        guard let calendar = eventStore.defaultCalendarForNewEvents else {
            throw ActionError.noDefaultCalendar
        }

        let event = EKEvent(eventStore: eventStore)
        event.title = title
        event.startDate = startDate
        event.endDate = startDate.addingTimeInterval(duration)
        event.calendar = calendar
        try eventStore.save(event, span: .thisEvent, commit: true)

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
        guard let calendar = eventStore.defaultCalendarForNewReminders() else {
            throw ActionError.noDefaultReminderList
        }

        let reminder = EKReminder(eventStore: eventStore)
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

        try eventStore.save(reminder, commit: true)

        return ActionReceipt(
            kind: .reminder,
            externalIdentifier: reminder.calendarItemIdentifier,
            title: title,
            createdAt: Date()
        )
    }

    private func ensureCalendarAccess() async -> Bool {
        let status = EKEventStore.authorizationStatus(for: .event)
        if hasUsableAccess(status, entityType: .event) {
            return true
        }
        if status == .notDetermined {
            return await requestCalendarAccess()
        }
        return false
    }

    private func ensureRemindersAccess() async -> Bool {
        let status = EKEventStore.authorizationStatus(for: .reminder)
        if hasUsableAccess(status, entityType: .reminder) {
            return true
        }
        if status == .notDetermined {
            return await requestRemindersAccess()
        }
        return false
    }

    private func hasUsableAccess(_ status: EKAuthorizationStatus, entityType: EKEntityType) -> Bool {
        if #available(macOS 14.0, *) {
            switch status {
            case .fullAccess:
                return true
            case .writeOnly:
                return entityType == .event
            case .authorized:
                return true
            default:
                return false
            }
        } else {
            return status == .authorized
        }
    }

    private func statusText(for status: EKAuthorizationStatus, entityType: EKEntityType) -> String {
        if #available(macOS 14.0, *) {
            switch status {
            case .notDetermined:
                return "尚未要求權限"
            case .restricted:
                return "系統限制存取"
            case .denied:
                return "已拒絕"
            case .authorized:
                return "已授權"
            case .fullAccess:
                return "完整存取已授權"
            case .writeOnly:
                return entityType == .event ? "僅寫入已授權" : "僅寫入"
            @unknown default:
                return "未知狀態"
            }
        } else {
            switch status {
            case .notDetermined:
                return "尚未要求權限"
            case .restricted:
                return "系統限制存取"
            case .denied:
                return "已拒絕"
            case .authorized:
                return "已授權"
            default:
                // macOS 13 不會產生 macOS 14 新增的 fullAccess / writeOnly，
                // 但使用新 SDK 編譯時，Swift 仍要求 switch 對已知 enum case 完整覆蓋。
                return "未知狀態"
            }
        }
    }

    private func requestLegacyAccess(to entityType: EKEntityType) async throws -> Bool {
        try await withCheckedThrowingContinuation { continuation in
            eventStore.requestAccess(to: entityType) { granted, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: granted)
                }
            }
        }
    }
}
