import AppKit
import SwiftUI

struct InboxView: View {
    @ObservedObject var store: CaptureStore
    @ObservedObject private var viewState: InboxViewState
    let onReview: (UUID) -> Void
    let onOpenLinkedTask: (String) -> Void

    init(
        store: CaptureStore,
        onReview: @escaping (UUID) -> Void,
        onOpenLinkedTask: @escaping (String) -> Void
    ) {
        self.store = store
        self.onReview = onReview
        self.onOpenLinkedTask = onOpenLinkedTask
        _viewState = ObservedObject(wrappedValue: InboxViewState())
    }

    private var visibleItems: [CaptureItem] {
        store.items.filter { item in
            let matchesFilter: Bool
            switch viewState.filter {
            case .inbox:
                matchesFilter = item.status == .inbox
            case .converted:
                matchesFilter = item.status == .converted
            case .done:
                matchesFilter = item.status == .done
            case .all:
                matchesFilter = true
            }

            let query = viewState.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            let smartTitle = item.interpretation?.title ?? ""
            let linkedTaskTitle = item.linkedGASTaskTitle ?? ""
            let linkedTaskID = item.linkedGASTaskID ?? ""
            let matchesSearch = query.isEmpty
                || item.text.localizedCaseInsensitiveContains(query)
                || smartTitle.localizedCaseInsensitiveContains(query)
                || linkedTaskTitle.localizedCaseInsensitiveContains(query)
                || linkedTaskID.localizedCaseInsensitiveContains(query)
            return matchesFilter && matchesSearch
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            if visibleItems.isEmpty {
                emptyState
            } else {
                itemList
            }
        }
        .frame(minWidth: 660, minHeight: 460)
    }

    private var header: some View {
        VStack(spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("DeskPet Inbox")
                        .font(.title2.bold())
                    Text("待處理 \(store.inboxCount) 件 · Inbox → Task Link")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if store.items.contains(where: { $0.status == .done }) {
                    Button("清除已完成") {
                        store.deleteCompleted()
                    }
                }
            }

            HStack(spacing: 10) {
                TextField(
                    "搜尋原文、分析標題或任務 ID",
                    text: Binding(
                        get: { viewState.searchText },
                        set: { viewState.searchText = $0 }
                    )
                )
                .textFieldStyle(.roundedBorder)

                Picker(
                    "篩選",
                    selection: Binding(
                        get: { viewState.filter },
                        set: { viewState.filter = $0 }
                    )
                ) {
                    ForEach(InboxFilter.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 330)
            }
        }
        .padding(18)
    }

    private var itemList: some View {
        List {
            ForEach(visibleItems) { item in
                HStack(alignment: .top, spacing: 12) {
                    statusControl(for: item)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(item.text)
                            .strikethrough(item.status == .done)
                            .foregroundStyle(item.status == .done ? .secondary : .primary)
                            .textSelection(.enabled)

                        if let interpretation = item.interpretation {
                            smartSummary(interpretation)
                        }

                        ForEach(item.actionReceipts.filter { $0.kind != .gasTask }) { receipt in
                            actionSummary(receipt)
                        }

                        if item.isConvertedToGASTask {
                            linkedTaskSummary(item)
                        }

                        Text(item.createdAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }

                    Spacer(minLength: 12)

                    VStack(alignment: .trailing, spacing: 7) {
                        Button(item.interpretation == nil ? "分析" : "檢視") {
                            onReview(item.id)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .help("讓 DeskPet 理解這筆內容；不會自動執行")

                        Button(role: .destructive) {
                            store.delete(id: item.id)
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                        .help("刪除")
                    }
                }
                .padding(.vertical, 6)
            }
        }
        .listStyle(.inset)
    }

    @ViewBuilder
    private func statusControl(for item: CaptureItem) -> some View {
        if item.status == .converted {
            Image(systemName: "arrow.triangle.branch")
                .font(.title3)
                .foregroundStyle(.green)
                .help("這筆 Inbox 已轉成校務任務系統任務")
        } else {
            Button {
                store.toggleDone(id: item.id)
            } label: {
                Image(systemName: item.status == .done ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
            }
            .buttonStyle(.plain)
            .help(item.status == .done ? "標回待處理" : "標記完成")
        }
    }

    private func smartSummary(_ interpretation: SmartInterpretation) -> some View {
        HStack(spacing: 7) {
            Label(interpretation.kind.rawValue, systemImage: interpretation.kind.symbolName)
                .font(.caption.weight(.semibold))

            Text(interpretation.title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            if let targetDate = interpretation.targetDate {
                Text("·")
                    .foregroundStyle(.tertiary)
                Text(targetDate.formatted(date: .numeric, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func actionSummary(_ receipt: ActionReceipt) -> some View {
        HStack(spacing: 6) {
            Image(systemName: receipt.kind.symbolName)
                .foregroundStyle(.green)
            Text("已加入 \(receipt.kind.displayName)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.green)
            if let externalID = receipt.externalIdentifier, !externalID.isEmpty {
                Text("· \(externalID)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Text("·")
                .foregroundStyle(.tertiary)
            Text(receipt.createdAt.formatted(date: .numeric, time: .shortened))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func linkedTaskSummary(_ item: CaptureItem) -> some View {
        HStack(spacing: 7) {
            Image(systemName: "link.circle.fill")
                .foregroundStyle(.green)

            Text("已轉成任務")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.green)

            if let title = item.linkedGASTaskTitle, !title.isEmpty {
                Text("· \(title)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            if let taskID = item.linkedGASTaskID, !taskID.isEmpty {
                Text("· \(taskID)")
                    .font(.caption2.monospaced())
                    .foregroundStyle(.tertiary)

                Button("開啟任務") {
                    openLinkedTask(item: item, taskID: taskID)
                }
                .buttonStyle(.link)
                .controlSize(.small)
            }
        }
    }

    private func openLinkedTask(item: CaptureItem, taskID: String) {
        if let rawURL = item.linkedGASTaskURL,
           let url = URL(string: rawURL),
           url.scheme == "https" {
            NSWorkspace.shared.open(url)
            return
        }
        onOpenLinkedTask(taskID)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Spacer()
            Image(systemName: viewState.searchText.isEmpty ? "tray" : "magnifyingglass")
                .font(.system(size: 34))
                .foregroundStyle(.secondary)
            Text(viewState.searchText.isEmpty ? "這裡目前沒有記事" : "找不到符合的記事")
                .font(.headline)
            Text(viewState.searchText.isEmpty ? "用桌寵或全域快捷鍵快速記下一件事。" : "換個關鍵字再試一次。")
                .font(.callout)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
