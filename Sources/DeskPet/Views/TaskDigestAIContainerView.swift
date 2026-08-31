import SwiftUI

struct TaskDigestAIContainerView: View {
    @ObservedObject var monitor: GASTaskAmbientMonitor
    @ObservedObject var gasConfiguration: GASTaskConfigurationStore
    @ObservedObject var aiConfiguration: AIConfigurationStore
    @ObservedObject var captureStore: CaptureStore
    @ObservedObject var workEventStore: WorkEventStore
    @ObservedObject var snoozeStore: SnoozeStore
    @ObservedObject var waitingAIContextStore: WaitingAIContextStore
    @ObservedObject var viewState: DailyWorkViewState
    let calendarQueryService: CalendarQueryService
    let onOpenTask: (GASTaskDigest.Task) -> Void
    let onOpenTaskAction: (GASTaskDigest.Task, GASTaskMutationKind) -> Void

    @State private var isShowingAIContext = false
    private let dailyWorkService = DailyWorkService()

    private var waitingItems: [WaitingItem] {
        dailyWorkService.snapshot(
            tasks: monitor.digest?.tasks ?? [],
            inboxItems: captureStore.items,
            events: workEventStore.events,
            snoozedUntil: snoozeStore.snoozedUntil
        ).waitingItems
    }

    var body: some View {
        TaskDigestView(
            monitor: monitor,
            gasConfiguration: gasConfiguration,
            captureStore: captureStore,
            workEventStore: workEventStore,
            snoozeStore: snoozeStore,
            viewState: viewState,
            calendarQueryService: calendarQueryService,
            onOpenTask: onOpenTask,
            onOpenTaskAction: onOpenTaskAction
        )
        .toolbar {
            ToolbarItem {
                Button {
                    isShowingAIContext = true
                } label: {
                    Label("AI 等待情境", systemImage: "sparkles")
                }
                .help("以 Gemini 補充 Waiting Radar 的阻塞與依賴情境；不會自動修改任務")
            }
        }
        .sheet(isPresented: $isShowingAIContext) {
            WaitingAIContextView(
                items: waitingItems,
                peerTasks: monitor.digest?.tasks ?? [],
                aiConfiguration: aiConfiguration,
                store: waitingAIContextStore,
                onOpenTask: onOpenTask,
                onFollowUp: { task in onOpenTaskAction(task, .followUp) }
            )
        }
    }
}

private struct WaitingAIContextView: View {
    let items: [WaitingItem]
    let peerTasks: [GASTaskDigest.Task]
    @ObservedObject var aiConfiguration: AIConfigurationStore
    @ObservedObject var store: WaitingAIContextStore
    let onOpenTask: (GASTaskDigest.Task) -> Void
    let onFollowUp: (GASTaskDigest.Task) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Waiting Intelligence + AI Context", systemImage: "sparkles")
                        .font(.title2.bold())
                    Text("規則風險仍是第一層；Gemini 只補充阻塞、依賴與語意情境，不會自動改狀態、期限或催辦。")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("完成") { dismiss() }
            }

            Divider()

            if !aiConfiguration.canUseAI {
                VStack(alignment: .leading, spacing: 8) {
                    Label("AI Context 尚未啟用", systemImage: "sparkles")
                        .font(.headline)
                    Text(aiConfiguration.hasAPIKey ? "請在設定中開啟 AI 功能。" : "請先在設定中啟用 AI 並設定 Gemini API Key。")
                        .foregroundStyle(.secondary)
                    Text("即使未啟用 AI，RC1.3 的 Waiting Risk、追蹤節奏與介入判斷仍會正常運作。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(14)
                .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
            } else if items.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "hourglass").font(.system(size: 32)).foregroundStyle(.secondary)
                    Text("目前沒有等待案件").font(.headline)
                    Text("有 Waiting 項目時，AI Context 才會提供情境分析。")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                HStack {
                    Text("AI 會傳送目前等待案件與最多 12 筆相關工作摘要至 Gemini，用於判斷可能的流程阻塞。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button(store.isBatchAnalyzing ? "分析中…" : "分析最值得關注的 3 件") {
                        Task {
                            await store.analyzePriority(items: items, peerTasks: peerTasks, limit: 3)
                        }
                    }
                    .disabled(store.isBatchAnalyzing)
                    .buttonStyle(.borderedProminent)
                }

                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(items) { item in
                            WaitingAIContextRow(
                                item: item,
                                assessment: store.assessment(for: item),
                                errorMessage: store.error(for: item.task.taskId),
                                isAnalyzing: store.isAnalyzing(taskID: item.task.taskId),
                                onAnalyze: {
                                    Task { await store.analyze(item: item, peerTasks: peerTasks) }
                                },
                                onOpenTask: { onOpenTask(item.task) },
                                onFollowUp: { onFollowUp(item.task) }
                            )
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .padding(20)
        .frame(minWidth: 780, minHeight: 600)
    }
}

private struct WaitingAIContextRow: View {
    let item: WaitingItem
    let assessment: WaitingAIContextAssessment?
    let errorMessage: String?
    let isAnalyzing: Bool
    let onAnalyze: () -> Void
    let onOpenTask: () -> Void
    let onFollowUp: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.task.name).font(.headline)
                    Text("規則風險 \(item.riskScore)/100 · \(item.riskLevel.label) · 已等待 \(item.waitingDays) 天 · \(item.waitingTarget.isEmpty ? "等待對象未填" : item.waitingTarget)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("查看任務", action: onOpenTask)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }

            if let assessment {
                let combinedScore = assessment.combinedRiskScore(baseRiskScore: item.riskScore)
                let combinedLevel = assessment.combinedRiskLevel(baseRiskScore: item.riskScore)
                HStack(spacing: 8) {
                    Text("AI 情境 \(signed(assessment.contextualRiskDelta))")
                        .font(.caption.bold())
                    Text(assessment.blockingImpact.label)
                        .font(.caption.bold())
                    Text("綜合建議 \(combinedScore)/100 · \(combinedLevel.label)")
                        .font(.caption.bold())
                    Spacer()
                    Text("信心 \(Int(assessment.confidence * 100))%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text("依賴判斷：\(assessment.dependencySummary)")
                    if !assessment.riskSignals.isEmpty {
                        Text("情境訊號：\(assessment.riskSignals.joined(separator: "；"))")
                    }
                    Text("AI 說明：\(assessment.rationale)")
                    Text("建議：\(assessment.recommendedAction)")
                        .fontWeight(.medium)
                }
                .font(.callout)

                HStack {
                    Text("AI 結果僅供判斷輔助；正式任務狀態仍以 GAS 與規則層為準。")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("重新分析", action: onAnalyze)
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    if combinedLevel >= .followUp {
                        Button("開啟催辦確認", action: onFollowUp)
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                    }
                }
            } else if isAnalyzing {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Gemini 正在補充阻塞與依賴情境…")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            } else {
                HStack {
                    if let errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("尚未進行情境分析。規則風險不受影響。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(errorMessage == nil ? "AI 情境分析" : "重新分析", action: onAnalyze)
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
            }
        }
        .padding(14)
        .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
    }

    private func signed(_ value: Int) -> String {
        value > 0 ? "+\(value)" : "\(value)"
    }
}
