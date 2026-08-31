import SwiftUI

enum DailyWorkSection: String, CaseIterable, Identifiable {
    case today = "今天"
    case waiting = "等待"
    case dailyWrap = "每日收工"
    case weeklyReview = "本週"
    var id: String { rawValue }
}

final class DailyWorkViewState: ObservableObject {
    @Published var selectedSection: DailyWorkSection = .today
    @Published var calendarEvents: [CalendarEventSummary] = []
    @Published var calendarContextMessage: String?
    @Published var isRefreshingCalendarContext = false
}

struct TaskDigestView: View {
    @ObservedObject var monitor: GASTaskAmbientMonitor
    @ObservedObject var gasConfiguration: GASTaskConfigurationStore
    @ObservedObject var captureStore: CaptureStore
    @ObservedObject var workEventStore: WorkEventStore
    @ObservedObject var snoozeStore: SnoozeStore
    @ObservedObject var viewState: DailyWorkViewState
    let calendarQueryService: CalendarQueryService
    let onOpenTask: (GASTaskDigest.Task) -> Void
    let onOpenTaskAction: (GASTaskDigest.Task, GASTaskMutationKind) -> Void

    private let service = DailyWorkService()
    private let contextEngine = WorkContextEngine()

    private var snapshot: DailyWorkSnapshot {
        service.snapshot(
            tasks: monitor.digest?.tasks ?? [],
            inboxItems: captureStore.items,
            events: workEventStore.events,
            snoozedUntil: snoozeStore.snoozedUntil
        )
    }

    private var contextSnapshot: WorkContextSnapshot {
        contextEngine.snapshot(
            tasks: monitor.digest?.tasks ?? [],
            inboxItems: captureStore.items,
            workEvents: workEventStore.events,
            calendarEvents: viewState.calendarEvents,
            snoozedUntil: snoozeStore.snoozedUntil
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            Picker("Daily Work", selection: $viewState.selectedSection) {
                ForEach(DailyWorkSection.allCases) { section in Text(section.rawValue).tag(section) }
            }
            .pickerStyle(.segmented)

            Divider()
            Group {
                switch viewState.selectedSection {
                case .today: todayView(snapshot.todayBrief)
                case .waiting: waitingView(snapshot.waitingItems)
                case .dailyWrap: dailyWrapView(snapshot.dailyWrap)
                case .weeklyReview: weeklyReviewView(snapshot.weeklyReview)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .padding(20)
        .frame(minWidth: 760, minHeight: 580)
        .task {
            snoozeStore.purgeExpired()
            await refreshCalendarContext()
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("今日工作")
                    .font(.title2.bold())
                Text(Self.dayFormatter.string(from: snapshot.todayBrief.date))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Text(monitor.statusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            PetWorkStateBadge(state: snapshot.petWorkState)
            Button(monitor.isRefreshing || viewState.isRefreshingCalendarContext ? "同步中…" : "重新同步") {
                Task {
                    await monitor.refresh(manual: true)
                    await refreshCalendarContext()
                }
            }
            .disabled(monitor.isRefreshing || viewState.isRefreshingCalendarContext)
        }
    }

    private func todayView(_ brief: TodayBrief) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                WorkContextOverviewView(
                    snapshot: contextSnapshot,
                    calendarContextMessage: viewState.calendarContextMessage,
                    onOpenTask: onOpenTask
                )

                HStack(spacing: 8) {
                    SummaryBadge(title: "逾期", value: brief.overdueCount, systemImage: "exclamationmark.triangle", tone: .red)
                    SummaryBadge(title: "今天", value: brief.dueTodayCount, systemImage: "calendar", tone: .blue)
                    SummaryBadge(title: "高優先", value: brief.highPriorityCount, systemImage: "flag.fill", tone: .orange)
                    SummaryBadge(title: "等待", value: brief.waitingCount, systemImage: "hourglass", tone: .purple)
                    SummaryBadge(title: "需追蹤", value: brief.followUpDueCount, systemImage: "bell.badge", tone: .red)
                    SummaryBadge(title: "Inbox", value: brief.pendingInboxCount, systemImage: "tray", tone: .secondary)
                }

                if !snapshot.followUpQueue.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("今天建議追蹤", systemImage: "dot.radiowaves.left.and.right")
                            .font(.headline)
                        ForEach(snapshot.followUpQueue.prefix(3)) { item in
                            Button {
                                onOpenTaskAction(item.task, .followUp)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(item.task.name).fontWeight(.medium)
                                        Text("\(item.riskLevel.label) · 等待 \(item.waitingDays) 天 · \(item.waitingTarget.isEmpty ? "等待對象未填" : item.waitingTarget)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text("風險 \(item.riskScore)")
                                        .font(.caption.bold())
                                }
                            }
                            .buttonStyle(.plain)
                            .padding(10)
                            .background(Color.red.opacity(0.05), in: RoundedRectangle(cornerRadius: 9))
                        }
                    }
                }

                Text("建議先處理")
                    .font(.headline)
                if brief.suggestions.isEmpty {
                    EmptyWorkView(title: "今天沒有急迫工作", detail: "Inbox 與工作日誌仍保留原始資料。", symbol: "checkmark.circle")
                        .frame(minHeight: 150)
                } else {
                    LazyVStack(spacing: 8) {
                        ForEach(Array(brief.suggestions.enumerated()), id: \.element.id) { index, candidate in
                            DailyTaskRow(
                                index: index + 1,
                                task: candidate.task,
                                tier: candidate.tier,
                                onOpen: { onOpenTask(candidate.task) },
                                onSnooze: { snooze(candidate.task, interval: $0) }
                            )
                        }
                    }
                }
            }
        }
    }

    private func waitingView(_ items: [WaitingItem]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("等待雷達").font(.headline)
                    Text("風險會綜合等待時間、優先度、截止日與催辦節奏；稍後提醒只暫停通知，不會讓案件從雷達消失。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("需追蹤 \(items.filter { $0.interventionRequired && !$0.isAlertSuppressed }.count)")
                    .font(.caption.bold())
            }
            if items.isEmpty {
                EmptyWorkView(title: "目前沒有等待項目", detail: "進入等待的工作會顯示在這裡。", symbol: "hourglass")
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(items) { item in
                            WaitingRadarRow(
                                item: item,
                                onOpen: { onOpenTask(item.task) },
                                onAction: { onOpenTaskAction(item.task, $0) },
                                onSnooze: { snooze(item.task, interval: $0) }
                            )
                        }
                    }
                }
            }
        }
    }

    private func dailyWrapView(_ wrap: DailyWrap) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    ReviewCount(title: "完成", value: wrap.count(.completed), color: .green)
                    ReviewCount(title: "推進", value: wrap.count(.progressed), color: .blue)
                    ReviewCount(title: "等待", value: wrap.count(.waiting), color: .purple)
                    ReviewCount(title: "新增", value: wrap.count(.created), color: .orange)
                    ReviewCount(title: "捕捉", value: wrap.count(.captured), color: .secondary)
                }
                ReviewList(title: "今日主要成果", values: wrap.mainResults, empty: "今天尚無工作事件")
                ReviewList(title: "尚未完成工作", values: wrap.unfinishedTasks.prefix(5).map(\.name), empty: "目前沒有未完成任務")
                ReviewList(title: "明日建議優先事項", values: wrap.tomorrowPriorities.map(\.task.name), empty: "目前沒有建議事項")
            }
        }
    }

    private func weeklyReviewView(_ review: WeeklyReview) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("週一至 \(Self.dayFormatter.string(from: review.interval.end.addingTimeInterval(-1)))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    ReviewCount(title: "完成", value: review.count(.completed), color: .green)
                    ReviewCount(title: "推進", value: review.count(.progressed), color: .blue)
                    ReviewCount(title: "等待", value: review.count(.waiting), color: .purple)
                    ReviewCount(title: "高風險等待", value: review.waitingCriticalCount, color: .red)
                    ReviewCount(title: "催辦", value: review.followUpCount, color: .orange)
                }
                Text(String(format: "目前等待案件平均 %.1f 天", review.waitingAverageDays))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                ReviewList(title: "本週成果", values: review.achievements, empty: "本週尚無工作事件")
                ReviewList(title: "仍在進行", values: review.inProgress.prefix(6).map(\.name), empty: "目前沒有進行中任務")
                ReviewList(title: "等待過久", values: review.waitingTooLong.map { "\($0.task.name)（\($0.waitingDays) 天｜\($0.riskLevel.label)）" }, empty: "沒有等待過久項目")
                ReviewList(title: "下週優先事項", values: review.nextWeekPriorities.map(\.task.name), empty: "目前沒有建議事項")
            }
        }
    }

    @MainActor
    private func refreshCalendarContext() async {
        guard !viewState.isRefreshingCalendarContext else { return }
        viewState.isRefreshingCalendarContext = true
        defer { viewState.isRefreshingCalendarContext = false }

        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "zh_TW")
        calendar.timeZone = TimeZone(identifier: "Asia/Taipei")!
        let start = calendar.startOfDay(for: Date())
        guard let end = calendar.date(byAdding: .day, value: 2, to: start) else { return }

        do {
            viewState.calendarEvents = try await calendarQueryService.events(in: DateInterval(start: start, end: end))
            viewState.calendarContextMessage = nil
        } catch {
            viewState.calendarEvents = []
            viewState.calendarContextMessage = "行事曆情境未載入；目前仍以任務、Inbox 與工作日誌產生建議。"
        }
    }

    private func snooze(_ task: GASTaskDigest.Task, interval: TimeInterval) {
        snoozeStore.snooze(taskID: task.taskId, until: Date().addingTimeInterval(interval))
    }

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_TW")
        formatter.timeZone = TimeZone(identifier: "Asia/Taipei")
        formatter.dateFormat = "yyyy年M月d日 EEEE"
        return formatter
    }()
}

struct PetWorkStateBadge: View {
    let state: PetWorkState

    var body: some View {
        Label(label, systemImage: symbol)
            .font(.caption.weight(.medium))
            .foregroundStyle(color)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(color.opacity(0.10), in: Capsule())
    }

    private var label: String {
        switch state {
        case .idle: return "待命"
        case .normal: return "工作中"
        case .attention: return "需要注意"
        case .waiting: return "等待中"
        case .success: return "今日有進展"
        case .sleep: return "休息"
        }
    }

    private var symbol: String {
        switch state {
        case .attention: return "exclamationmark.triangle.fill"
        case .waiting: return "hourglass"
        case .success: return "checkmark.circle.fill"
        case .sleep: return "moon.zzz.fill"
        case .idle: return "pawprint"
        case .normal: return "circle.dotted"
        }
    }

    private var color: Color {
        switch state {
        case .attention: return .red
        case .waiting: return .purple
        case .success: return .green
        case .sleep, .idle, .normal: return .secondary
        }
    }
}

private struct SummaryBadge: View {
    let title: String
    let value: Int
    let systemImage: String
    let tone: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Label(title, systemImage: systemImage).font(.caption).foregroundStyle(.secondary)
            Text("\(value)").font(.title2.bold()).foregroundStyle(tone)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
    }
}

private struct EmptyWorkView: View {
    let title: String
    let detail: String
    let symbol: String
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: symbol).font(.system(size: 32)).foregroundStyle(.secondary)
            Text(title).font(.headline)
            Text(detail).font(.callout).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct DailyTaskRow: View {
    let index: Int
    let task: GASTaskDigest.Task
    let tier: DailyWorkPriorityTier
    let onOpen: () -> Void
    let onSnooze: (TimeInterval) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(index)").font(.headline).frame(width: 22)
            VStack(alignment: .leading, spacing: 4) {
                Text(task.name).font(.body.weight(.medium))
                if let next = task.nextAction, !next.isEmpty { Text("下一步：\(next)").font(.caption).foregroundStyle(.secondary).lineLimit(2) }
                Text([task.status, task.deadlineText].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text(tierLabel).font(.caption.bold()).foregroundStyle(tierColor)
            Button("開始處理", action: onOpen).buttonStyle(.borderedProminent).controlSize(.small)
            SnoozeMenu(onSnooze: onSnooze)
        }
        .padding(11)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
    }

    private var tierLabel: String {
        switch tier { case .overdue: return "逾期"; case .dueToday: return "今天"; case .highPriority: return "高"; case .waiting: return "等待"; case .normal: return "一般" }
    }
    private var tierColor: Color { tier == .overdue ? .red : (tier == .waiting ? .purple : (tier == .highPriority ? .orange : .secondary)) }
}

private struct WaitingRadarRow: View {
    let item: WaitingItem
    let onOpen: () -> Void
    let onAction: (GASTaskMutationKind) -> Void
    let onSnooze: (TimeInterval) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 7) {
                        Text(item.task.name).font(.headline)
                        Text(item.riskLevel.label)
                            .font(.caption.bold())
                            .foregroundStyle(riskColor)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(riskColor.opacity(0.10), in: Capsule())
                        if item.isAlertSuppressed {
                            Label("提醒暫停", systemImage: "bell.slash")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Text("等待對象：\(item.waitingTarget.isEmpty ? "未填寫" : item.waitingTarget) · \(item.waitingDays) 天\(item.isHeuristic ? "（推估）" : "") · 風險 \(item.riskScore)")
                        .font(.caption).foregroundStyle(.secondary)
                    if let recommended = item.recommendedFollowUpAt {
                        Text("建議追蹤：\(Self.dateFormatter.string(from: recommended))")
                            .font(.caption)
                            .foregroundStyle(item.interventionRequired && !item.isAlertSuppressed ? Color.orange : Color.secondary)
                    }
                    if item.followUpCount > 0 {
                        let last = item.lastFollowUpAt.map { Self.dateFormatter.string(from: $0) } ?? "—"
                        Text("已催辦 \(item.followUpCount) 次 · 最近一次 \(last)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let deadline = item.task.deadlineText { Text("截止：\(deadline)").font(.caption).foregroundStyle(.secondary) }
                    if let progress = item.task.progress, !progress.isEmpty { Text("最近進度：\(progress)").font(.callout) }
                }
                Spacer()
                Button("查看任務", action: onOpen).buttonStyle(.bordered).controlSize(.small)
            }
            HStack {
                Button("記錄已催辦") { onAction(.followUp) }
                    .buttonStyle(.bordered)
                Button("修改等待對象") { onAction(.changeWaiting) }
                Button("解除等待") { onAction(.clearWaiting) }
                Spacer()
                SnoozeMenu(onSnooze: onSnooze)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(12)
        .background(riskColor.opacity(item.riskLevel >= .followUp ? 0.07 : 0.04), in: RoundedRectangle(cornerRadius: 10))
    }

    private var riskColor: Color {
        switch item.riskLevel {
        case .normal: return .secondary
        case .watch: return .orange
        case .followUp: return .purple
        case .critical: return .red
        }
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_TW")
        formatter.timeZone = TimeZone(identifier: "Asia/Taipei")
        formatter.dateFormat = "M/d HH:mm"
        return formatter
    }()
}

private struct SnoozeMenu: View {
    let onSnooze: (TimeInterval) -> Void
    var body: some View {
        Menu("稍後提醒") {
            Button("1 小時後") { onSnooze(3600) }
            Button("今天下午") { onSnooze(4 * 3600) }
            Button("明天") { onSnooze(24 * 3600) }
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }
}

private struct ReviewCount: View {
    let title: String
    let value: Int
    let color: Color
    var body: some View {
        VStack(alignment: .leading) { Text(title).font(.caption).foregroundStyle(.secondary); Text("\(value)").font(.title2.bold()).foregroundStyle(color) }
            .padding(10).frame(maxWidth: .infinity, alignment: .leading).background(Color.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 9))
    }
}

private struct ReviewList: View {
    let title: String
    let values: [String]
    let empty: String
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title).font(.headline)
            if values.isEmpty { Text(empty).foregroundStyle(.secondary) }
            else { ForEach(Array(values.enumerated()), id: \.offset) { _, value in Label(value, systemImage: "checkmark.circle").font(.callout) } }
        }
        .padding(12).frame(maxWidth: .infinity, alignment: .leading).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
    }
}