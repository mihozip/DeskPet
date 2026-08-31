import Foundation

struct WorkContextEngine {
    private let dailyWorkService: DailyWorkService
    private let calendar: Calendar

    init(timeZone: TimeZone = TimeZone(identifier: "Asia/Taipei")!) {
        dailyWorkService = DailyWorkService(timeZone: timeZone)

        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "zh_TW")
        calendar.timeZone = timeZone
        self.calendar = calendar
    }

    func snapshot(
        tasks: [GASTaskDigest.Task],
        inboxItems: [CaptureItem],
        workEvents: [WorkEvent],
        calendarEvents: [CalendarEventSummary],
        snoozedUntil: [String: Date] = [:],
        now: Date = Date()
    ) -> WorkContextSnapshot {
        let openTasks = tasks.filter { !Self.isDone($0) }
        let actionableTasks = openTasks.filter { task in
            guard let snoozeExpiry = snoozedUntil[task.taskId] else { return true }
            return snoozeExpiry <= now
        }
        let candidates = dailyWorkService.sortedCandidates(from: actionableTasks, now: now)
        let waitingItems = dailyWorkService.waitingItems(
            from: openTasks,
            events: workEvents,
            snoozedUntil: snoozedUntil,
            now: now
        )
        let interventionWaiting = waitingItems.first { $0.interventionRequired && !$0.isAlertSuppressed }
        let pendingInbox = inboxItems
            .filter { $0.status == .inbox }
            .sorted {
                if $0.createdAt != $1.createdAt { return $0.createdAt < $1.createdAt }
                return $0.id.uuidString < $1.id.uuidString
            }
        let visibleCalendar = calendarEvents
            .filter { $0.endDate > now }
            .sorted {
                if $0.startDate != $1.startDate { return $0.startDate < $1.startDate }
                return $0.title.localizedStandardCompare($1.title) == .orderedAscending
            }
        // All-day events provide background context but should not continuously
        // replace the user's active focus headline throughout the day.
        let currentEvent = visibleCalendar.first { !$0.isAllDay && $0.startDate <= now && $0.endDate > now }
        let nextEvent = visibleCalendar.first { $0.startDate > now }
        let recentActivity = workEvents
            .filter { $0.timestamp <= now && calendar.isDate($0.timestamp, inSameDayAs: now) }
            .max { $0.timestamp < $1.timestamp }

        var used = Set<String>()
        var nowItems: [WorkContextItem] = []
        var nextItems: [WorkContextItem] = []
        var laterItems: [WorkContextItem] = []

        func append(_ item: WorkContextItem, to bucket: inout [WorkContextItem], limit: Int) {
            guard bucket.count < limit, used.insert(item.id).inserted else { return }
            bucket.append(item)
        }

        if let currentEvent {
            append(calendarItem(currentEvent, bucket: .now), to: &nowItems, limit: 3)
        }

        if let interventionWaiting {
            append(waitingItem(interventionWaiting, bucket: .now), to: &nowItems, limit: 3)
        }

        for candidate in candidates
        where !Self.isWaiting(candidate.task) && [.overdue, .dueToday, .highPriority].contains(candidate.tier) {
            append(taskItem(candidate, bucket: .now), to: &nowItems, limit: 3)
        }

        if nowItems.isEmpty,
           let first = candidates.first(where: { !Self.isWaiting($0.task) }) {
            append(taskItem(first, bucket: .now), to: &nowItems, limit: 3)
        }

        if nowItems.isEmpty, let firstInbox = pendingInbox.first {
            append(inboxItem(firstInbox, bucket: .now, now: now), to: &nowItems, limit: 3)
        }

        if let nextEvent,
           calendar.isDate(nextEvent.startDate, inSameDayAs: now) || nextEvent.startDate.timeIntervalSince(now) <= 8 * 3600 {
            append(calendarItem(nextEvent, bucket: .next), to: &nextItems, limit: 3)
        }

        for candidate in candidates where !Self.isWaiting(candidate.task) {
            append(taskItem(candidate, bucket: .next), to: &nextItems, limit: 3)
        }

        if nextItems.isEmpty, let firstInbox = pendingInbox.first {
            append(inboxItem(firstInbox, bucket: .next, now: now), to: &nextItems, limit: 3)
        }

        for waiting in waitingItems {
            append(waitingItem(waiting, bucket: .later), to: &laterItems, limit: 5)
        }

        for event in visibleCalendar where event.startDate > now {
            append(calendarItem(event, bucket: .later), to: &laterItems, limit: 5)
        }

        for candidate in candidates {
            append(taskItem(candidate, bucket: .later), to: &laterItems, limit: 5)
        }

        for item in pendingInbox where now.timeIntervalSince(item.createdAt) >= 24 * 3600 {
            append(inboxItem(item, bucket: .later, now: now), to: &laterItems, limit: 5)
        }

        return WorkContextSnapshot(
            generatedAt: now,
            headline: headline(
                nowItems: nowItems,
                currentEvent: currentEvent,
                nextEvent: nextEvent,
                interventionWaiting: interventionWaiting,
                pendingInboxCount: pendingInbox.count,
                now: now
            ),
            currentEvent: currentEvent,
            nextEvent: nextEvent,
            recentActivity: recentActivity,
            nowItems: nowItems,
            nextItems: nextItems,
            laterItems: laterItems
        )
    }

    private func headline(
        nowItems: [WorkContextItem],
        currentEvent: CalendarEventSummary?,
        nextEvent: CalendarEventSummary?,
        interventionWaiting: WaitingItem?,
        pendingInboxCount: Int,
        now: Date
    ) -> String {
        if let currentEvent {
            return "現在正在進行：\(currentEvent.title)"
        }

        if let interventionWaiting {
            return "等待案件需要介入：\(interventionWaiting.task.name)（已等 \(interventionWaiting.waitingDays) 天）"
        }

        if let nextEvent,
           nextEvent.startDate.timeIntervalSince(now) >= 0,
           nextEvent.startDate.timeIntervalSince(now) <= 90 * 60 {
            if let task = nowItems.compactMap(\.task).first {
                return "\(timeText(nextEvent.startDate)) 有「\(nextEvent.title)」，先處理「\(task.name)」"
            }
            return "\(timeText(nextEvent.startDate)) 的下一個行程：\(nextEvent.title)"
        }

        if let task = nowItems.compactMap(\.task).first {
            return "現在最值得處理：\(task.name)"
        }

        if let nextEvent {
            return "下一個行程：\(nextEvent.title)"
        }

        if pendingInboxCount > 0 {
            return "Inbox 還有 \(pendingInboxCount) 則待整理"
        }

        return "目前沒有急迫工作"
    }

    private func taskItem(_ candidate: NextActionCandidate, bucket: WorkContextBucket) -> WorkContextItem {
        let task = candidate.task
        var details: [String] = []

        if Self.isWaiting(task) {
            let target = task.waitingFor?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            details.append(target.isEmpty ? "等待中" : "等待：\(target)")
        } else {
            switch candidate.tier {
            case .overdue: details.append("逾期")
            case .dueToday: details.append("今天到期")
            case .highPriority: details.append("高優先")
            case .waiting: details.append("等待中")
            case .normal: break
            }
        }

        if let deadline = task.deadlineText, !deadline.isEmpty {
            details.append("截止 \(deadline)")
        }
        if let nextAction = task.nextAction?.trimmingCharacters(in: .whitespacesAndNewlines), !nextAction.isEmpty {
            details.append("下一步：\(nextAction)")
        }

        return WorkContextItem(
            id: "task:\(task.taskId)",
            bucket: bucket,
            title: task.name,
            detail: details.isEmpty ? task.status : details.joined(separator: " · "),
            source: .task(task)
        )
    }

    private func waitingItem(_ waiting: WaitingItem, bucket: WorkContextBucket) -> WorkContextItem {
        var details: [String] = []
        details.append(waiting.waitingTarget.isEmpty ? "等待對象未填" : "等待：\(waiting.waitingTarget)")
        details.append("已 \(waiting.waitingDays) 天")
        details.append(waiting.riskLevel.label)
        if waiting.followUpCount > 0 { details.append("已催辦 \(waiting.followUpCount) 次") }
        if waiting.isAlertSuppressed { details.append("提醒已暫停") }

        return WorkContextItem(
            id: "task:\(waiting.task.taskId)",
            bucket: bucket,
            title: waiting.task.name,
            detail: details.joined(separator: " · "),
            source: .task(waiting.task)
        )
    }

    private func calendarItem(_ event: CalendarEventSummary, bucket: WorkContextBucket) -> WorkContextItem {
        var details = [event.isAllDay ? "全天" : "\(timeText(event.startDate))–\(timeText(event.endDate))"]
        if let location = event.location?.trimmingCharacters(in: .whitespacesAndNewlines), !location.isEmpty {
            details.append(location)
        }
        return WorkContextItem(
            id: "calendar:\(event.id)",
            bucket: bucket,
            title: event.title,
            detail: details.joined(separator: " · "),
            source: .calendar(event)
        )
    }

    private func inboxItem(_ item: CaptureItem, bucket: WorkContextBucket, now: Date) -> WorkContextItem {
        let days = max(
            0,
            calendar.dateComponents(
                [.day],
                from: calendar.startOfDay(for: item.createdAt),
                to: calendar.startOfDay(for: now)
            ).day ?? 0
        )
        let ageText = days == 0 ? "今天捕捉" : "\(days) 天前捕捉"
        return WorkContextItem(
            id: "inbox:\(item.id.uuidString)",
            bucket: bucket,
            title: item.text,
            detail: "Inbox · \(ageText)",
            source: .inbox(item)
        )
    }

    private func timeText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_TW")
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private static func isDone(_ task: GASTaskDigest.Task) -> Bool {
        ["已完成", "取消", "completed", "done", "cancelled"].contains(
            task.status?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        )
    }

    private static func isWaiting(_ task: GASTaskDigest.Task) -> Bool {
        let target = task.waitingFor?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let status = task.status?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        return !target.isEmpty || task.isWaiting || ["等待他人", "待確認", "waiting", "blocked"].contains(status)
    }
}
