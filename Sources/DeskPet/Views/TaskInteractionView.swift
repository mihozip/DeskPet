import SwiftUI

struct TaskInteractionView: View {
    @ObservedObject var model: TaskInteractionViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            Divider()
            taskCard
            actionPicker

            if let preview = model.preview {
                Divider()
                actionEditor(for: preview.action)
                changePreview(preview)
                confirmationBar
            }

            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(minWidth: 590, minHeight: 560)
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(model.taskActionTitle)
                    .font(.title2.bold())
                Text("所有寫入都要經過這個確認畫面。")
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if model.canOpenDetailURL {
                Button("開啟詳細資料") { model.openDetailURL() }
            }
        }
    }

    private var taskCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(model.task.name)
                .font(.headline)
            HStack(spacing: 10) {
                if let category = model.task.category, !category.isEmpty { Text(category) }
                if let status = model.task.status, !status.isEmpty { Text(status) }
                if let priority = model.task.priority, !priority.isEmpty { Text("優先：\(priority)") }
                if let deadline = model.task.deadlineText { Text(deadline) }
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            if let waiting = model.task.waitingFor, !waiting.isEmpty {
                Text("等待對象：\(waiting)")
                    .font(.callout)
            }
            if let progress = model.task.progress, !progress.isEmpty {
                Text("最近進度：\(progress)")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private var actionPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("要做什麼？")
                .font(.headline)
            HStack(spacing: 10) {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 125))], spacing: 8) {
                ForEach(GASTaskMutationKind.allCases) { action in
                    Button {
                        model.choose(action)
                    } label: {
                        Label(action.title, systemImage: action.systemImage)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                }
            }
        }
    }

    @ViewBuilder
    private func actionEditor(for action: GASTaskMutationKind) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if action == .postpone {
                DatePicker("新的截止日期", selection: $model.newDueDate, displayedComponents: .date)
                Toggle("設定截止時間", isOn: $model.includeTime)
                if model.includeTime {
                    DatePicker("新的截止時間", selection: $model.newDueTime, displayedComponents: .hourAndMinute)
                }
            }

            if action == .updateProgress {
                Text("下一步行動")
                    .font(.subheadline.weight(.medium))
                TextField("例如：請校長確認預算", text: $model.nextAction, axis: .vertical)
                    .lineLimit(2...3)
            }

            if action == .changeWaiting {
                Text("等待對象")
                    .font(.subheadline.weight(.medium))
                TextField("例如：校長、廠商", text: $model.waitingTarget)
            }

            Text("進度備註")
                .font(.subheadline.weight(.medium))
            TextField("例如：已收到廠商回覆", text: $model.note, axis: .vertical)
                .lineLimit(2...4)
        }
    }

    private func changePreview(_ preview: GASTaskMutationPreview) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("變更預覽")
                .font(.headline)
            if let after = preview.statusAfter, after != preview.statusBefore {
                ChangeRow(label: "狀態", before: preview.statusBefore, after: after)
            }
            if let after = preview.dueDateAfter, after != preview.dueDateBefore {
                ChangeRow(label: "截止日期", before: preview.dueDateBefore, after: after)
            }
            if let after = preview.dueTimeAfter, after != preview.dueTimeBefore {
                ChangeRow(label: "截止時間", before: preview.dueTimeBefore, after: after.isEmpty ? "清除" : after)
            }
            if let after = preview.waitingForAfter, after != preview.waitingForBefore {
                ChangeRow(label: "等待對象", before: preview.waitingForBefore, after: after.isEmpty ? "清除" : after)
            }
            if let after = preview.progressAfter, after != preview.progressBefore {
                ChangeRow(label: "最近進度", before: preview.progressBefore, after: after.isEmpty ? "清除" : after)
            }
            if let after = preview.nextActionAfter, after != preview.nextActionBefore {
                ChangeRow(label: "下一步行動", before: preview.nextActionBefore, after: after.isEmpty ? "清除" : after)
            }
        }
        .padding(12)
        .background(Color.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
    }

    private var confirmationBar: some View {
        HStack {
            Image(systemName: model.didSucceed ? "checkmark.circle.fill" : "info.circle")
                .foregroundStyle(model.didSucceed ? Color.green : Color.secondary)
            Text(model.statusMessage)
                .font(.callout)
                .foregroundStyle(.secondary)
            Spacer()
            Button(model.isSubmitting ? "寫入中…" : "確認寫入校務任務系統") {
                Task { await model.submit() }
            }
            .buttonStyle(.borderedProminent)
            .disabled(model.isSubmitting || model.didSucceed)
        }
    }
}

private struct ChangeRow: View {
    let label: String
    let before: String
    let after: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label)
                .frame(width: 72, alignment: .leading)
                .foregroundStyle(.secondary)
            Text(before.isEmpty ? "—" : before)
                .foregroundStyle(.secondary)
            Image(systemName: "arrow.right")
                .foregroundStyle(.secondary)
            Text(after.isEmpty ? "—" : after)
                .fontWeight(.medium)
        }
        .font(.callout)
    }
}
