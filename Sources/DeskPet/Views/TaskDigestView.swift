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
}

struct TaskDigestView: View {
    @ObservedObject var monitor: GASTaskAmbientMonitor
    @ObservedObject var gasConfiguration: GASTaskConfigurationStore
    @ObservedObject var captureStore: CaptureStore
    @ObservedObject var workEventStore: WorkEventStore
    @ObservedObject var snoozeStore: SnoozeStore
    @ObservedObject var viewState: DailyWorkViewState
    let onOpenTask: (GASTaskDigest.Task) -> Void
    let onOpenTaskAction: (GASTaskDigest.Task, GASTaskMutationKind) -> Void

    private let service = DailyWorkService()

    private var snapshot: DailyWorkSnapshot {
        service.snapshot(
            tasks: monitor.digest?.tasks ?? [],
            inboxItems: captureStore.items,
            events: workEventStore.events,
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
        .onAppear { snoozeStore.purgeExpired() }
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
            Button(monitor.isRefreshing ? "同步中…" : "重新同步") {
                Task { await monitor.refresh(manual: true) }
            }
            .disabled(monitor.isRefreshing)
        }
    }

    private func todayView(_ brief: TodayBrief) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                SummaryBadge(title: "逾期", value: brief.overdueCount, systemImage: "exclamationmark.triangle", tone: .red)
                SummaryBadge(title: "今天", value: brief.dueTodayCount, systemImage: "calendar", tone: .blue)
                SummaryBadge(title: "高優先", value: brief.highPriorityCount, systemImage: "flag.fill", tone: .orange)
                SummaryBadge(title: "等待", value: brief.waitingCount, systemImage: "hourglass", tone: .purple)
                SummaryBadge(title: "Inbox", value: brief.pendingInboxCount, systemImage: "tray", tone: .secondary)
            }

            Text("建議先處理")
                .font(.headline)
            if brief.suggestions.isEmpty {
                EmptyWorkView(title: "今天沒有急迫工作", detail: "Inbox 與工作日誌仍保留原始資料。", symbol: "checkmark.circle")
            } else {
                ScrollView {
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
                Text("等待雷達").font(.headline)
                Spacer()
                Text("等待天數可能由更新時間推估")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if items.isEmpty {
                EmptyWorkView(title: "目前沒有等待項目", detail: "稍後提醒到期的項目會自動回到雷達。", symbol: "hourglass")
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
                    ReviewCount(title: "新增", value: review.count(.created), color: .orange)
                    ReviewCount(title: "Inbox", value: review.count(.captured), color: .secondary)
                }
                ReviewList(title: "本週成果", values: review.achievements, empty: "本週尚無工作事件")
                ReviewList(title: "仍在進行", values: review.inProgress.prefix(6).map(\.name), empty: "目前沒有進行中任務")
                ReviewList(title: "等待過久", values: review.waitingTooLong.map { "\($0.task.name)（\($0.waitingDays) 天）" }, empty: "沒有等待過久項目")
                ReviewList(title: "下週優先事項", values: review.nextWeekPriorities.map(\.task.name), empty: "目前沒有建議事項")
            }
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
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.task.name).font(.headline)
                    Text("等待對象：\(item.waitingTarget.isEmpty ? "未填寫" : item.waitingTarget) · \(item.waitingDays) 天\(item.isHeuristic ? "（推估）" : "")")
                        .font(.caption).foregroundStyle(.secondary)
                    if let deadline = item.task.deadlineText { Text("截止：\(deadline)").font(.caption).foregroundStyle(.secondary) }
                    if let progress = item.task.progress, !progress.isEmpty { Text("最近進度：\(progress)").font(.callout) }
                }
                Spacer()
                Button("查看任務", action: onOpen).buttonStyle(.bordered).controlSize(.small)
            }
            HStack {
                Button("記錄已催辦") { onAction(.followUp) }
                Button("修改等待對象") { onAction(.changeWaiting) }
                Button("解除等待") { onAction(.clearWaiting) }
                Spacer()
                SnoozeMenu(onSnooze: onSnooze)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(12)
        .background(Color.purple.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
    }
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
