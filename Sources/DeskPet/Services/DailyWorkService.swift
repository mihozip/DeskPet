import Foundation

struct DailyWorkService {
    let calendar: Calendar
    let waitingTooLongDays: Int

    init(timeZone: TimeZone = TimeZone(identifier: "Asia/Taipei")!, waitingTooLongDays: Int = 3) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "zh_TW")
        calendar.timeZone = timeZone
        calendar.firstWeekday = 2
        calendar.minimumDaysInFirstWeek = 4
        self.calendar = calendar
        self.waitingTooLongDays = max(1, waitingTooLongDays)
    }

    func snapshot(
        tasks: [GASTaskDigest.Task],
        inboxItems: [CaptureItem],
        events: [WorkEvent],
        snoozedUntil: [String: Date] = [:],
        now: Date = Date()
    ) -> DailyWorkSnapshot {
        let openTasks = tasks.filter { !Self.isDone($0) }
        let actionableTasks = openTasks.filter { !isSnoozed($0, snoozedUntil: snoozedUntil, now: now) }
        let candidates = sortedCandidates(from: actionableTasks, now: now)
        let waiting = waitingItems(
            from: openTasks,
            events: events,
            snoozedUntil: snoozedUntil,
            now: now
        )
        let followUpQueue = waiting
            .filter { $0.interventionRequired && !$0.isAlertSuppressed }
            .sorted {
                if $0.riskScore != $1.riskScore { return $0.riskScore > $1.riskScore }
                if $0.waitingDays != $1.waitingDays { return $0.waitingDays > $1.waitingDays }
                return $0.task.taskId < $1.task.taskId
            }
        let brief = TodayBrief(
            date: calendar.startOfDay(for: now),
            overdueCount: candidates.filter { $0.tier == .overdue }.count,
            dueTodayCount: candidates.filter { $0.tier == .dueToday }.count,
            highPriorityCount: candidates.filter { $0.tier == .highPriority }.count,
            waitingCount: waiting.count,
            followUpDueCount: followUpQueue.count,
            pendingInboxCount: inboxItems.filter { $0.status == .inbox }.count,
            suggestions: Array(candidates.prefix(5))
        )
        let daily = dailyWrap(events: events, tasks: actionableTasks, candidates: candidates, now: now)
        let weekly = weeklyReview(events: events, tasks: actionableTasks, waitingItems: waiting, candidates: candidates, now: now)
        return DailyWorkSnapshot(
            generatedAt: now,
            todayBrief: brief,
            waitingItems: waiting,
            followUpQueue: followUpQueue,
            dailyWrap: daily,
            weeklyReview: weekly,
            petWorkState: petState(
                brief: brief,
                waitingItems: waiting,
                followUpQueue: followUpQueue,
                dailyWrap: daily,
                activeTaskCount: actionableTasks.count,
                now: now
            )
        )
    }

    func sortedCandidates(from tasks: [GASTaskDigest.Task], now: Date) -> [NextActionCandidate] {
        tasks.map { NextActionCandidate(task: $0, tier: priorityTier(for: $0, now: now)) }
            .sorted { lhs, rhs in
                if lhs.tier != rhs.tier { return lhs.tier < rhs.tier }
                let leftDeadline = deadline(for: lhs.task) ?? .distantFuture
                let rightDeadline = deadline(for: rhs.task) ?? .distantFuture
                if leftDeadline != rightDeadline { return leftDeadline < rightDeadline }
                let leftPriority = priorityRank(lhs.task.priority)
                let rightPriority = priorityRank(rhs.task.priority)
                if leftPriority != rightPriority { return leftPriority < rightPriority }
                let leftUpdated = dateTime(lhs.task.updatedAt) ?? .distantPast
                let rightUpdated = dateTime(rhs.task.updatedAt) ?? .distantPast
                if leftUpdated != rightUpdated { return leftUpdated < rightUpdated }
                let nameOrder = lhs.task.name.localizedStandardCompare(rhs.task.name)
                if nameOrder != .orderedSame { return nameOrder == .orderedAscending }
                return lhs.task.taskId < rhs.task.taskId
            }
    }

    func priorityTier(for task: GASTaskDigest.Task, now: Date) -> DailyWorkPriorityTier {
        if task.isOverdue || isDeadline(task, beforeDayOf: now) { return .overdue }
        if task.isDueToday || isDeadline(task, sameDayAs: now) { return .dueToday }
        if task.isUrgent || priorityRank(task.priority) == 0 { return .highPriority }
        if Self.isWaiting(task) { return .waiting }
        return .normal
    }

    func waitingItems(
        from tasks: [GASTaskDigest.Task],
        events: [WorkEvent],
        snoozedUntil: [String: Date] = [:],
        now: Date
    ) -> [WaitingItem] {
        tasks.compactMap { task -> WaitingItem? in
            guard Self.isWaiting(task), !Self.isDone(task) else { return nil }
            let target = task.waitingFor?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let taskEvents = events.filter { $0.referenceID == task.taskId }
            let waitingEventDate = taskEvents
                .filter { Self.eventIndicatesWaiting($0) }
                .map(\.timestamp)
                .max()
            let fallback = dateTime(task.updatedAt)
            let since = waitingEventDate ?? fallback
            let days = since.map {
                max(0, calendar.dateComponents([.day], from: calendar.startOfDay(for: $0), to: calendar.startOfDay(for: now)).day ?? 0)
            } ?? 0

            let followUps = taskEvents
                .filter { event in
                    guard Self.eventIndicatesFollowUp(event) else { return false }
                    guard let since else { return true }
                    return event.timestamp >= since
                }
                .sorted { $0.timestamp < $1.timestamp }
            let lastFollowUpAt = followUps.last?.timestamp
            let recommended = recommendedFollowUpDate(
                task: task,
                waitingSince: since,
                lastFollowUpAt: lastFollowUpAt,
                now: now
            )
            let score = waitingRiskScore(
                task: task,
                waitingTarget: target,
                waitingDays: days,
                followUpCount: followUps.count,
                recommendedFollowUpAt: recommended,
                now: now
            )
            let level = waitingRiskLevel(score: score)
            let dueForFollowUp = recommended.map { $0 <= now } ?? (days >= waitingTooLongDays)
            let suppressedUntil = snoozedUntil[task.taskId].flatMap { $0 > now ? $0 : nil }

            return WaitingItem(
                task: task,
                waitingTarget: target,
                waitingSince: since,
                waitingDays: days,
                isHeuristic: waitingEventDate == nil,
                lastFollowUpAt: lastFollowUpAt,
                followUpCount: followUps.count,
                recommendedFollowUpAt: recommended,
                riskScore: score,
                riskLevel: level,
                interventionRequired: level >= .followUp || dueForFollowUp,
                alertSuppressedUntil: suppressedUntil
            )
        }
        .sorted {
            if $0.riskScore != $1.riskScore { return $0.riskScore > $1.riskScore }
            if $0.waitingDays != $1.waitingDays { return $0.waitingDays > $1.waitingDays }
            return $0.task.taskId < $1.task.taskId
        }
    }

    func classify(_ event: WorkEvent) -> DailyWorkEventCategory? {
        switch event.kind {
        case .taskCompleted:
            return .completed
        case .taskCreated:
            return .created
        case .noteCreated:
            return .captured
        case .taskUpdated where Self.eventIndicatesWaiting(event):
            return .waiting
        case .taskUpdated, .taskLinked, .receivedReply, .postponed, .calendarCreated, .reminderCreated:
            return .progressed
        case .manualDiaryNote:
            return nil
        }
    }

    private func dailyWrap(
        events: [WorkEvent],
        tasks: [GASTaskDigest.Task],
        candidates: [NextActionCandidate],
        now: Date
    ) -> DailyWrap {
        let dayEvents = events.filter { calendar.isDate($0.timestamp, inSameDayAs: now) }.sorted { $0.timestamp < $1.timestamp }
        let counts = countsByCategory(dayEvents)
        let results = uniqueTitles(from: dayEvents.filter {
            guard let category = classify($0) else { return false }
            return [.completed, .progressed, .waiting, .created].contains(category)
        })
        return DailyWrap(
            date: calendar.startOfDay(for: now),
            events: dayEvents,
            counts: counts,
            mainResults: Array(results.prefix(5)),
            unfinishedTasks: Array(tasks.prefix(10)),
            tomorrowPriorities: Array(candidates.prefix(5))
        )
    }

    private func weeklyReview(
        events: [WorkEvent],
        tasks: [GASTaskDigest.Task],
        waitingItems: [WaitingItem],
        candidates: [NextActionCandidate],
        now: Date
    ) -> WeeklyReview {
        let start = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? calendar.startOfDay(for: now)
        let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? now
        let interval = DateInterval(start: start, end: end)
        let weekEvents = events.filter { $0.timestamp >= start && $0.timestamp < end }.sorted { $0.timestamp < $1.timestamp }
        let achievements = uniqueTitles(from: weekEvents.filter {
            guard let category = classify($0) else { return false }
            return category == .completed || category == .progressed
        })
        let averageDays: Double
        if waitingItems.isEmpty {
            averageDays = 0
        } else {
            averageDays = Double(waitingItems.reduce(0) { $0 + $1.waitingDays }) / Double(waitingItems.count)
        }
        return WeeklyReview(
            interval: interval,
            events: weekEvents,
            counts: countsByCategory(weekEvents),
            achievements: Array(achievements.prefix(8)),
            inProgress: Array(tasks.prefix(12)),
            waitingTooLong: waitingItems.filter { $0.waitingDays >= waitingTooLongDays },
            waitingAverageDays: averageDays,
            waitingCriticalCount: waitingItems.filter { $0.riskLevel == .critical }.count,
            followUpCount: waitingItems.reduce(0) { $0 + $1.followUpCount },
            nextWeekPriorities: Array(candidates.prefix(5))
        )
    }

    private func petState(
        brief: TodayBrief,
        waitingItems: [WaitingItem],
        followUpQueue: [WaitingItem],
        dailyWrap: DailyWrap,
        activeTaskCount: Int,
        now: Date
    ) -> PetWorkState {
        if brief.overdueCount > 0 || brief.dueTodayCount > 0 || followUpQueue.contains(where: { $0.riskLevel == .critical }) {
            return .attention
        }
        if !followUpQueue.isEmpty || waitingItems.contains(where: { $0.waitingDays >= waitingTooLongDays && !$0.isAlertSuppressed }) {
            return .waiting
        }
        if activeTaskCount == 0 {
            let hour = calendar.component(.hour, from: now)
            return hour < 7 || hour >= 21 ? .sleep : .idle
        }
        if brief.highPriorityCount == 0 && dailyWrap.count(.completed) > 0 { return .success }
        return .normal
    }

    private func recommendedFollowUpDate(
        task: GASTaskDigest.Task,
        waitingSince: Date?,
        lastFollowUpAt: Date?,
        now: Date
    ) -> Date? {
        let base: Date?
        if let lastFollowUpAt {
            base = calendar.date(byAdding: .day, value: 2, to: lastFollowUpAt)
        } else if let waitingSince {
            base = calendar.date(byAdding: .day, value: waitingTooLongDays, to: waitingSince)
        } else {
            base = nil
        }

        guard let deadline = deadline(for: task) else { return base }
        if deadline <= now { return calendar.startOfDay(for: now) }
        let deadlineWarning = calendar.date(byAdding: .day, value: -1, to: deadline) ?? deadline
        guard let base else { return deadlineWarning }
        return min(base, deadlineWarning)
    }

    private func waitingRiskScore(
        task: GASTaskDigest.Task,
        waitingTarget: String,
        waitingDays: Int,
        followUpCount: Int,
        recommendedFollowUpAt: Date?,
        now: Date
    ) -> Int {
        var score = 0

        switch waitingDays {
        case 0...2: break
        case 3...4: score += 15
        case 5...6: score += 25
        default: score += 35
        }

        switch priorityRank(task.priority) {
        case 0: score += 20
        case 1: score += 5
        default: break
        }

        if waitingTarget.isEmpty { score += 10 }

        if let deadline = deadline(for: task) {
            let remaining = deadline.timeIntervalSince(now)
            if remaining < 0 {
                score += 35
            } else if remaining <= 24 * 3600 {
                score += 30
            } else if remaining <= 3 * 24 * 3600 {
                score += 20
            } else if remaining <= 7 * 24 * 3600 {
                score += 10
            }
        }

        if recommendedFollowUpAt.map({ $0 <= now }) == true { score += 20 }
        if followUpCount == 0 && waitingDays >= 5 { score += 10 }

        return min(100, score)
    }

    private func waitingRiskLevel(score: Int) -> WaitingRiskLevel {
        switch score {
        case 75...: return .critical
        case 50..<75: return .followUp
        case 25..<50: return .watch
        default: return .normal
        }
    }

    private func countsByCategory(_ events: [WorkEvent]) -> [DailyWorkEventCategory: Int] {
        events.reduce(into: [:]) { result, event in
            if let category = classify(event) { result[category, default: 0] += 1 }
        }
    }

    private func uniqueTitles(from events: [WorkEvent]) -> [String] {
        var seen = Set<String>()
        return events.reversed().compactMap { event in
            let title = event.title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty, seen.insert(title).inserted else { return nil }
            return title
        }
    }

    private func deadline(for task: GASTaskDigest.Task) -> Date? {
        let date = task.dueDate?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !date.isEmpty else { return nil }
        let time = task.dueTime?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return dateTime(time.isEmpty ? "\(date) 23:59" : "\(date) \(time)")
    }

    private func isDeadline(_ task: GASTaskDigest.Task, beforeDayOf date: Date) -> Bool {
        guard let deadline = deadline(for: task) else { return false }
        return deadline < calendar.startOfDay(for: date)
    }

    private func isDeadline(_ task: GASTaskDigest.Task, sameDayAs date: Date) -> Bool {
        guard let deadline = deadline(for: task) else { return false }
        return calendar.isDate(deadline, inSameDayAs: date)
    }

    private func dateTime(_ raw: String?) -> Date? {
        guard let raw = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else { return nil }
        for format in ["yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd HH:mm", "yyyy-MM-dd'T'HH:mm:ssXXXXX", "yyyy/MM/dd HH:mm:ss"] {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.calendar = calendar
            formatter.timeZone = calendar.timeZone
            formatter.dateFormat = format
            if let value = formatter.date(from: raw) { return value }
        }
        return nil
    }

    private func priorityRank(_ priority: String?) -> Int {
        switch priority?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "高", "緊急", "urgent", "high", "p0", "p1": return 0
        case "中", "medium", "normal", "p2": return 1
        case "低", "low", "p3": return 2
        default: return 3
        }
    }

    private func isSnoozed(_ task: GASTaskDigest.Task, snoozedUntil: [String: Date], now: Date) -> Bool {
        guard let until = snoozedUntil[task.taskId] else { return false }
        return until > now
    }

    private static func isDone(_ task: GASTaskDigest.Task) -> Bool {
        ["已完成", "取消", "completed", "done", "cancelled"].contains(task.status?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? "")
    }

    private static func isWaiting(_ task: GASTaskDigest.Task) -> Bool {
        let target = task.waitingFor?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let status = task.status?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        return !target.isEmpty || task.isWaiting || ["等待他人", "待確認", "waiting", "blocked"].contains(status)
    }

    private static func eventIndicatesWaiting(_ event: WorkEvent) -> Bool {
        let text = [event.title, event.detail ?? ""].joined(separator: " ").lowercased()
        if text.contains("解除等待") || text.contains("結束等待") { return false }
        return text.contains("轉入等待")
            || text.contains("等待對象")
            || text.contains(" waiting for ")
            || (event.detail ?? "").trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("等待 ")
    }

    private static func eventIndicatesFollowUp(_ event: WorkEvent) -> Bool {
        let text = [event.title, event.detail ?? ""].joined(separator: " ").lowercased()
        return text.contains("已催辦")
            || text.contains("催辦")
            || text.contains("追蹤")
            || text.contains("follow up")
            || text.contains("follow-up")
    }
}
