import SwiftUI

struct WorkDiaryView: View {
    @ObservedObject var model: WorkDiaryViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            Divider()
            summaryCards
            manualNoteArea
            Divider()
            timeline
        }
        .padding(20)
        .frame(minWidth: 720, minHeight: 650)
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("每日工作日誌")
                    .font(.title2.bold())
                Text(WorkDiaryViewModel.dayFormatter.string(from: model.selectedDate))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button { model.previousDay() } label: { Image(systemName: "chevron.left") }
            Button("今天") { model.goToday() }
                .disabled(model.isToday)
            Button { model.nextDay() } label: { Image(systemName: "chevron.right") }

            Button("複製日誌") { model.copyDiaryToPasteboard() }
                .buttonStyle(.borderedProminent)
        }
    }

    private var summaryCards: some View {
        HStack(spacing: 10) {
            summaryCard(title: "完成", value: model.completedEvents.count, symbol: "checkmark.circle.fill")
            summaryCard(title: "進展", value: model.progressEvents.count, symbol: "arrow.up.right.circle.fill")
            summaryCard(title: "紀錄", value: model.noteEvents.count, symbol: "note.text")
            summaryCard(title: "事件", value: model.dayEvents.count, symbol: "clock.fill")
        }
    }

    private func summaryCard(title: String, value: Int, symbol: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.title3)
            VStack(alignment: .leading, spacing: 1) {
                Text("\(value)")
                    .font(.title3.bold())
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
    }

    private var manualNoteArea: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("補充今天沒被系統捕捉到的工作")
                .font(.headline)

            TextField("例如：和校長確認冷氣工程先做二樓", text: $model.manualNote, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(2...4)

            HStack {
                if let status = model.statusMessage {
                    Text(status)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("顯示事件 JSON") { model.revealEventsFile() }
                Button("加入日誌") { model.addManualNote() }
                    .buttonStyle(.borderedProminent)
            }
        }
    }

    private var timeline: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("今日時間軸")
                .font(.headline)

            if model.dayEvents.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "book.closed")
                        .font(.system(size: 30))
                        .foregroundStyle(Color.secondary)
                    Text("今天還沒有工作紀錄")
                        .font(.headline)
                    Text("快速記事、建立任務、完成／延期等動作會自動出現在這裡。")
                        .foregroundStyle(Color.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(model.dayEvents) { event in
                            WorkEventRow(
                                event: event,
                                onDelete: event.kind == .manualDiaryNote ? { model.deleteManualNote(id: event.id) } : nil
                            )
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .frame(maxHeight: .infinity)
    }
}

private struct WorkEventRow: View {
    let event: WorkEvent
    let onDelete: (() -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: event.kind.systemImage)
                .font(.system(size: 16, weight: .semibold))
                .frame(width: 28, height: 28)
                .background(Color.secondary.opacity(0.10), in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(event.title)
                        .font(.body.weight(.medium))
                    Spacer()
                    Text(WorkDiaryViewModel.timeFormatter.string(from: event.timestamp))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 6) {
                    Text(event.kind.displayName)
                    Text("·")
                    Text(event.source.displayName)
                    if let category = event.category, !category.isEmpty {
                        Text("·")
                        Text(category)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                if let detail = event.detail, !detail.isEmpty, detail != event.title {
                    Text(detail)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }

            if let onDelete {
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .help("刪除這筆手動日誌")
            }
        }
        .padding(10)
        .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
    }
}
