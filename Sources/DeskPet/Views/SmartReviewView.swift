import SwiftUI

struct SmartReviewView: View {
    @ObservedObject var model: SmartReviewViewModel
    let onSaveAndClose: () -> Void
    let onClose: () -> Void
    let onOpenTask: (GASTaskDigest.Task) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            Divider()
            originalTextSection
            interpretationSection
            Divider()
            actionSection
            Spacer(minLength: 0)
            Divider()
            actions
        }
        .padding(24)
        .frame(minWidth: 640, minHeight: 700)
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Smart Inbox 分析")
                    .font(.title2.bold())
                Text("先理解、再確認；外部動作一律由你按下建立按鈕後才執行。")
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text("信心度 \(model.confidenceLabel)").font(.caption.weight(.semibold))
                Text(model.sourceLabel).font(.caption2).foregroundStyle(.secondary)
            }
        }
    }

    private var originalTextSection: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("原始內容").font(.headline)
            Text(model.originalText)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
        }
    }

    private var interpretationSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("DeskPet 的理解").font(.headline)
                Spacer()
                if model.isAIAnalyzing {
                    ProgressView().controlSize(.small)
                    Text("AI 分析中").font(.caption).foregroundStyle(.secondary)
                }
            }

            Picker("類型", selection: Binding(get: { model.kind }, set: { model.kind = $0 })) {
                ForEach(CaptureKind.allCases) { kind in
                    Label(kind.rawValue, systemImage: kind.symbolName).tag(kind)
                }
            }
            .pickerStyle(.segmented)
            .disabled(model.isLockedAfterAction)

            TextField("標題", text: Binding(get: { model.title }, set: { model.title = $0 }))
                .textFieldStyle(.roundedBorder)
                .disabled(model.isLockedAfterAction)

            Toggle("包含時間", isOn: Binding(get: { model.hasTargetDate }, set: { model.hasTargetDate = $0 }))
                .disabled(model.isLockedAfterAction)

            if model.hasTargetDate {
                DatePicker(
                    model.kind == .event ? "行程時間" : "提醒／目標時間",
                    selection: Binding(get: { model.targetDate }, set: { model.targetDate = $0 })
                )
                .datePickerStyle(.field)
                .disabled(model.isLockedAfterAction)
            }

            if model.kind == .task {
                HStack(spacing: 16) {
                    Picker("行政分類", selection: $model.gasCategory) {
                        ForEach(model.gasCategories, id: \.self) { Text($0).tag($0) }
                    }
                    .frame(maxWidth: .infinity)

                    Picker("優先級", selection: $model.gasPriority) {
                        ForEach(model.gasPriorities, id: \.self) { Text($0).tag($0) }
                    }
                    .frame(width: 180)
                }
                .disabled(model.isLockedAfterAction)
            }

            Text(model.explanation)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let status = model.aiStatusMessage {
                Text(status)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var actionSection: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack {
                Text("Action Layer").font(.headline)
                Spacer()
                if model.isExecutingAction { ProgressView().controlSize(.small) }
            }

            Text(model.actionHint)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if model.isCheckingDuplicates {
                HStack(spacing: 7) {
                    ProgressView().controlSize(.small)
                    Text("Duplicate Guard 檢查中…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if let message = model.duplicateCheckMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(model.duplicateCandidates.isEmpty ? Color.secondary : Color.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !model.duplicateCandidates.isEmpty {
                duplicateGuardSection
            }

            if !model.actionReceipts.isEmpty {
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(model.actionReceipts) { receipt in
                        HStack(spacing: 6) {
                            Image(systemName: receipt.kind.symbolName).foregroundStyle(.green)
                            Text("已建立到 \(receipt.kind.displayName)")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.green)
                            if let id = receipt.externalIdentifier, !id.isEmpty {
                                Text("· \(id)").font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            switch model.kind {
            case .note:
                EmptyView()
            case .task:
                HStack(spacing: 10) {
                    Button(model.hasReceipt(.gasTask) ? "已加入總務工作台" : "加入總務工作台") {
                        Task { await model.createGASTask() }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!model.canCreateGASTask)

                    Button(model.hasReceipt(.reminder) ? "已加入提醒事項" : "加入提醒事項") {
                        Task { await model.createReminder() }
                    }
                    .disabled(!model.canCreateReminder)
                }

                if !model.canUseGASConnector && !model.hasReceipt(.gasTask) {
                    Text("總務工作台尚未啟用或缺少 API Token；可到設定完成串接。")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            case .event:
                Button(model.hasReceipt(.calendarEvent) ? "已加入行事曆" : "加入行事曆") {
                    Task { await model.createCalendarEvent() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!model.canCreateCalendarEvent)
            }

            if let status = model.actionStatusMessage {
                Text(status)
                    .font(.caption)
                    .foregroundStyle(model.actionReceipts.isEmpty ? Color.secondary : Color.green)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var duplicateGuardSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Label("可能重複", systemImage: "exclamationmark.triangle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.orange)
                Spacer()
                Text("不會自動合併")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            ForEach(model.duplicateCandidates) { candidate in
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(candidate.source.displayName)
                            .font(.caption.weight(.semibold))
                        Text("相似度 \(candidate.similarityLabel)")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                        if let status = candidate.statusText, !status.isEmpty {
                            Text("· \(status)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }

                    Text(candidate.title)
                        .font(.callout.weight(.semibold))
                        .lineLimit(2)

                    if let detail = candidate.detail, !detail.isEmpty, detail != candidate.title {
                        Text(detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }

                    HStack(spacing: 10) {
                        if let task = candidate.task {
                            Button("查看原任務") { onOpenTask(task) }
                                .controlSize(.small)
                            Button("合併到原任務") { model.mergeIntoExistingTask(candidate) }
                                .controlSize(.small)
                                .buttonStyle(.borderedProminent)
                        } else if candidate.source == .inbox {
                            Button("刪除這筆，保留原 Inbox") {
                                model.discardAsDuplicateOfInbox(candidate)
                                onSaveAndClose()
                            }
                            .controlSize(.small)
                        }
                    }
                }
                .padding(10)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 9))
            }

            HStack {
                Spacer()
                Button("仍建立新任務") {
                    Task { await model.createGASTaskAnyway() }
                }
                .controlSize(.small)
            }

            Text("「合併到原任務」只建立 Inbox → Task 關聯並留下 Work Diary 補充紀錄，不會覆寫既有 GAS 任務內容。")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 11))
    }

    private var actions: some View {
        HStack {
            Button("本機重算") { model.reanalyzeLocal() }
                .disabled(model.isAIAnalyzing || model.isExecutingAction || model.isLockedAfterAction)

            Button("AI 分析") { Task { await model.analyzeWithAI() } }
                .disabled(model.isAIAnalyzing || model.isExecutingAction || !model.canUseAI)

            Button("保持記事") {
                model.keepAsNote()
                onSaveAndClose()
            }
            .disabled(model.isAIAnalyzing || model.isExecutingAction || model.isLockedAfterAction)

            Spacer()

            Button("關閉") { onClose() }

            Button("儲存理解") {
                model.save()
                onSaveAndClose()
            }
            .keyboardShortcut(.defaultAction)
            .disabled(model.isAIAnalyzing || model.isExecutingAction || model.isLockedAfterAction)
        }
    }
}
