import SwiftUI

struct PetRootView: View {
    @ObservedObject var model: PetViewModel
    @ObservedObject var ambientMonitor: GASTaskAmbientMonitor
    @ObservedObject var dailyPreferences: DailyUsePreferencesStore
    @ObservedObject var gasConfiguration: GASTaskConfigurationStore
    @ObservedObject var workEventStore: WorkEventStore
    @ObservedObject var snoozeStore: SnoozeStore

    let onOpenInbox: () -> Void
    let onOpenTaskDigest: () -> Void
    let onOpenDiary: () -> Void
    let onOpenCalendarQuery: () -> Void
    let onOpenNaturalAction: () -> Void
    let onOpenVoiceAction: () -> Void
    let onOpenSettings: () -> Void
    let onOpenDiagnostics: () -> Void
    let shortcutLabel: () -> String
    let onDragChanged: (CGSize) -> Void
    let onDragEnded: () -> Void

    private var workSnapshot: DailyWorkSnapshot {
        DailyWorkService().snapshot(
            tasks: ambientMonitor.digest?.tasks ?? [],
            inboxItems: model.store.items,
            events: workEventStore.events,
            snoozedUntil: snoozeStore.snoozedUntil
        )
    }

    private var effectivePetState: PetState {
        guard model.state == .idle else { return model.state }
        switch workSnapshot.petWorkState {
        case .success: return .success
        case .sleep: return .sleeping
        case .idle, .normal, .attention, .waiting: return .idle
        }
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Color.clear

            VStack(alignment: .trailing, spacing: 4) {
                CaptureBubbleView(model: model, shortcutLabel: shortcutLabel)
                    .padding(.trailing, 30)

                if model.state == .idle {
                    if gasConfiguration.isLinked {
                        AmbientBriefingBubbleView(monitor: ambientMonitor, gasConfiguration: gasConfiguration)
                            .padding(.trailing, 30)
                    }

                    PetWorkStateBadge(state: workSnapshot.petWorkState)
                        .padding(.trailing, 30)
                }

                PetFaceView(state: effectivePetState, preferences: dailyPreferences)
                    .background {
                        Rectangle()
                            .fill(Color.black.opacity(0.001))
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { model.petTapped() }
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 4)
                            .onChanged { value in onDragChanged(value.translation) }
                            .onEnded { _ in onDragEnded() }
                    )
                    .contextMenu {
                        Button("快速記事（\(shortcutLabel())）") { model.beginCapture() }

                        Menu("工作") {
                            Button("開啟 Inbox") { onOpenInbox() }
                            if gasConfiguration.isLinked {
                                Button("今日工作") { onOpenTaskDigest() }
                            }
                            Button("每日工作日誌…") { onOpenDiary() }
                        }

                        Menu("查詢與輸入") {
                            Button("查詢行事曆…") { onOpenCalendarQuery() }
                            if gasConfiguration.isLinked {
                                Button("自然語句操作…") { onOpenNaturalAction() }
                                Button("語音操作（⌃⌥V）") { onOpenVoiceAction() }
                            }
                        }

                        Menu("工具") {
                            if gasConfiguration.isLinked {
                                Button("立即同步校務任務系統") {
                                    Task { await ambientMonitor.refresh(manual: true) }
                                }
                                Divider()
                            }

                            Button("設定…") { onOpenSettings() }
                            Button("系統診斷…") { onOpenDiagnostics() }
                            Button("顯示 Inbox JSON") { model.store.revealInboxFile() }
                        }

                        Divider()

                        if model.state == .sleeping {
                            Button("叫醒") { model.wake() }
                        } else {
                            Button("睡覺") { model.sleep() }
                        }

                        Button("退出 DeskPet") { model.quit() }
                    }
            }
        }
        .frame(width: 400, height: 220)
        .accessibilityLabel(gasConfiguration.workbenchTitle)
    }
}
