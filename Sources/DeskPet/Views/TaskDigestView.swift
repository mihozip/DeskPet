import SwiftUI

struct TaskDigestView: View {
    @ObservedObject var monitor: GASTaskAmbientMonitor
    @ObservedObject var gasConfiguration: GASTaskConfigurationStore
    let onOpenTask: (GASTaskDigest.Task) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            Divider()

            if let digest = monitor.digest {
                summary(digest.summary)
                Divider()
                taskList(digest.tasks)
            } else {
                VStack(spacing: 10) {
                    Image(systemName: "tray")
                        .font(.system(size: 34))
                        .foregroundStyle(.secondary)
                    Text("尚未取得任務摘要")
                        .font(.headline)
                    Text("按右上角「重新同步」從校務任務系統讀取任務。")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(minWidth: 660, minHeight: 500)
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(gasConfiguration.taskDigestTitle)
                    .font(.title2.bold())
                Text(monitor.statusMessage)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(monitor.isRefreshing ? "同步中…" : "重新同步") {
                Task { await monitor.refresh(manual: true) }
            }
            .disabled(monitor.isRefreshing)
        }
    }

    private func summary(_ summary: GASTaskDigest.Summary) -> some View {
        HStack(spacing: 10) {
            SummaryBadge(title: "進行中", value: summary.active, systemImage: "list.bullet", tone: .secondary)
            SummaryBadge(title: "今天", value: summary.dueToday, systemImage: "calendar", tone: .blue)
            SummaryBadge(title: "逾期", value: summary.overdue, systemImage: "exclamationmark.triangle", tone: .red)
            SummaryBadge(title: "高優先", value: summary.urgent, systemImage: "flag.fill", tone: .orange)
            SummaryBadge(title: "等待", value: summary.waiting, systemImage: "hourglass", tone: .purple)
        }
    }

    private func taskList(_ tasks: [GASTaskDigest.Task]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("需要注意的任務")
                .font(.headline)

            if tasks.isEmpty {
                Text("目前沒有進行中的任務。")
                    .foregroundStyle(.secondary)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(tasks) { task in
                            Button { onOpenTask(task) } label: {
                                TaskDigestRow(task: task)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
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
            Label(title, systemImage: systemImage)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("\(value)")
                .font(.title2.bold())
                .foregroundStyle(tone)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
    }
}

private struct TaskDigestRow: View {
    let task: GASTaskDigest.Task

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: leadingSymbol)
                .foregroundStyle(leadingColor)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 4) {
                Text(task.name)
                    .font(.body.weight(.medium))

                HStack(spacing: 8) {
                    if let category = task.category, !category.isEmpty {
                        Text(category)
                    }
                    if let status = task.status, !status.isEmpty {
                        Text(status)
                    }
                    if let deadline = task.deadlineText {
                        Text(deadline)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                if let next = task.nextAction, !next.isEmpty, next != task.name {
                    Text(next)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer()

            if task.isUrgent {
                Text("高")
                    .font(.caption.bold())
                    .foregroundStyle(Color.orange)
            }

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)

        }
        .padding(10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
    }

    private var leadingSymbol: String {
        if task.isOverdue { return "exclamationmark.triangle.fill" }
        if task.isDueToday { return "calendar.badge.clock" }
        if task.isWaiting { return "hourglass" }
        return "circle"
    }

    private var leadingColor: Color {
        if task.isOverdue { return Color.red }
        if task.isDueToday { return Color.blue }
        if task.isWaiting { return Color.purple }
        return Color.secondary
    }
}
