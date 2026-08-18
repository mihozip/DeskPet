import SwiftUI

struct WorkContextOverviewView: View {
    let snapshot: WorkContextSnapshot
    let calendarContextMessage: String?
    let onOpenTask: (GASTaskDigest.Task) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 5) {
                Label("白帥帥情境", systemImage: "scope")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(snapshot.headline)
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)

                if let recent = snapshot.recentActivity {
                    Text("最近進度：\(recent.title)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                if let calendarContextMessage {
                    Text(calendarContextMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))

            HStack(alignment: .top, spacing: 10) {
                ContextBucketCard(
                    title: "現在",
                    symbol: "bolt.fill",
                    items: snapshot.nowItems,
                    emptyText: "目前沒有需要立即處理的項目",
                    onOpenTask: onOpenTask
                )
                ContextBucketCard(
                    title: "接著",
                    symbol: "arrow.right.circle.fill",
                    items: snapshot.nextItems,
                    emptyText: "暫時沒有下一步建議",
                    onOpenTask: onOpenTask
                )
                ContextBucketCard(
                    title: "稍後",
                    symbol: "clock.fill",
                    items: snapshot.laterItems,
                    emptyText: "目前沒有需要追蹤的稍後事項",
                    onOpenTask: onOpenTask
                )
            }
        }
    }
}

private struct ContextBucketCard: View {
    let title: String
    let symbol: String
    let items: [WorkContextItem]
    let emptyText: String
    let onOpenTask: (GASTaskDigest.Task) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: symbol)
                .font(.headline)

            if items.isEmpty {
                Text(emptyText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ForEach(items) { item in
                    ContextItemRow(item: item, onOpenTask: onOpenTask)
                    if item.id != items.last?.id {
                        Divider()
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(11)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct ContextItemRow: View {
    let item: WorkContextItem
    let onOpenTask: (GASTaskDigest.Task) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 7) {
            Image(systemName: symbol)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 14)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.callout.weight(.medium))
                    .lineLimit(2)
                if let detail = item.detail, !detail.isEmpty {
                    Text(detail)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
            }

            Spacer(minLength: 4)

            if let task = item.task {
                Button {
                    onOpenTask(task)
                } label: {
                    Image(systemName: "arrow.up.right.square")
                }
                .buttonStyle(.plain)
                .help("開啟任務")
            }
        }
    }

    private var symbol: String {
        switch item.source {
        case .task(_): return "checklist"
        case .calendar(_): return "calendar"
        case .inbox(_): return "tray"
        }
    }
}
