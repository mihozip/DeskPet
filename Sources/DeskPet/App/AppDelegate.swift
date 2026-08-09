import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let workEventStore = WorkEventStore()
    private lazy var store = CaptureStore(workEventStore: workEventStore)
    private let aiConfiguration = AIConfigurationStore()
    private let actionService = CalendarActionService()
    private let gasConfiguration = GASTaskConfigurationStore()
    private let dailyPreferences = DailyUsePreferencesStore()
    private let launchAtLogin = LaunchAtLoginService()
    private let softwareUpdate = SoftwareUpdateService()
    private lazy var gasConnector = GASTaskConnector(configuration: gasConfiguration)
    private lazy var ambientMonitor = GASTaskAmbientMonitor(configuration: gasConfiguration, connector: gasConnector)
    private var panelController: PetPanelController?
    private var inboxWindowController: InboxWindowController?
    private var settingsWindowController: SettingsWindowController?
    private var smartReviewWindowController: SmartReviewWindowController?
    private var taskDigestWindowController: TaskDigestWindowController?
    private var taskInteractionWindowController: TaskInteractionWindowController?
    private var naturalTaskCommandWindowController: NaturalTaskCommandWindowController?
    private var workDiaryWindowController: WorkDiaryWindowController?
    private var hotKeyService: GlobalHotKeyService?
    private var voiceHotKeyService: VoiceHotKeyService?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let localInterpreter = LocalIntentInterpreter()
        let aiInterpreter = GeminiIntentInterpreter(configuration: aiConfiguration)

        let interactionController = TaskInteractionWindowController(
            connector: gasConnector,
            monitor: ambientMonitor,
            workEventStore: workEventStore
        )
        taskInteractionWindowController = interactionController

        let reviewController = SmartReviewWindowController(
            store: store,
            localInterpreter: localInterpreter,
            aiInterpreter: aiInterpreter,
            aiConfiguration: aiConfiguration,
            actionService: actionService,
            gasConfiguration: gasConfiguration,
            gasConnector: gasConnector,
            workEventStore: workEventStore,
            onOpenTask: { [weak interactionController] task in
                interactionController?.show(task: task)
            }
        )
        smartReviewWindowController = reviewController

        let naturalActionController = NaturalTaskCommandWindowController(
            monitor: ambientMonitor,
            connector: gasConnector,
            aiConfiguration: aiConfiguration,
            onOpenInteraction: { [weak interactionController] task, action, note, dueDate in
                interactionController?.show(
                    task: task,
                    preselectedAction: action,
                    prefilledNote: note,
                    prefilledDueDate: dueDate
                )
            }
        )
        naturalTaskCommandWindowController = naturalActionController

        let digestController = TaskDigestWindowController(
            monitor: ambientMonitor,
            onOpenTask: { [weak interactionController] task in interactionController?.show(task: task) }
        )
        taskDigestWindowController = digestController

        let linkedTaskMonitor = ambientMonitor
        let linkedTaskConnector = gasConnector
        let inboxController = InboxWindowController(
            store: store,
            onReview: { [weak reviewController] itemID in reviewController?.showReview(itemID: itemID) },
            onOpenLinkedTask: { [weak interactionController, weak digestController, weak linkedTaskMonitor, weak linkedTaskConnector] taskID in
                Task { @MainActor in
                    if let task = linkedTaskMonitor?.digest?.tasks.first(where: { $0.taskId == taskID }) {
                        interactionController?.show(task: task)
                        return
                    }

                    if let connector = linkedTaskConnector,
                       let latest = try? await connector.fetchTaskDigest(limit: 30),
                       let task = latest.tasks.first(where: { $0.taskId == taskID }) {
                        interactionController?.show(task: task)
                        return
                    }

                    // 已完成或不在摘要前 30 筆時，至少帶使用者回總務摘要；Inbox 仍保留 taskId 可供搜尋。
                    digestController?.showDigest()
                }
            }
        )
        inboxWindowController = inboxController

        let diaryController = WorkDiaryWindowController(store: workEventStore)
        workDiaryWindowController = diaryController

        let hotKeyService = GlobalHotKeyService()
        self.hotKeyService = hotKeyService

        let diagnostics = SelfDiagnosticsService(
            hotKeyService: hotKeyService,
            aiConfiguration: aiConfiguration,
            actionService: actionService,
            gasConfiguration: gasConfiguration,
            ambientMonitor: ambientMonitor,
            launchAtLogin: launchAtLogin,
            workEventStore: workEventStore
        )

        let settingsController = SettingsWindowController(
            hotKeyService: hotKeyService,
            aiConfiguration: aiConfiguration,
            actionService: actionService,
            gasConfiguration: gasConfiguration,
            gasConnector: gasConnector,
            ambientMonitor: ambientMonitor,
            dailyPreferences: dailyPreferences,
            launchAtLogin: launchAtLogin,
            softwareUpdate: softwareUpdate,
            diagnostics: diagnostics
        )
        settingsWindowController = settingsController

        let panelController = PetPanelController(
            store: store,
            ambientMonitor: ambientMonitor,
            dailyPreferences: dailyPreferences,
            onOpenInbox: { [weak inboxController] in inboxController?.showInbox() },
            onOpenTaskDigest: { [weak digestController] in digestController?.showDigest() },
            onOpenDiary: { [weak diaryController] in diaryController?.showDiary() },
            onOpenNaturalAction: { [weak naturalActionController] in naturalActionController?.showCommandWindow() },
            onOpenVoiceAction: { [weak naturalActionController] in naturalActionController?.showCommandWindow(autoStartVoice: true) },
            onOpenSettings: { [weak settingsController] in settingsController?.showSettings() },
            onOpenDiagnostics: { [weak settingsController] in settingsController?.showDiagnostics() },
            shortcutLabel: { [weak hotKeyService] in hotKeyService?.activeShortcutLabel ?? "快捷鍵" }
        )
        self.panelController = panelController
        panelController.show()
        ambientMonitor.start()
        softwareUpdate.checkIfDue()

        let registered = hotKeyService.register { [weak panelController] in panelController?.showCapture() }
        if !registered {
            NSLog("DeskPet: global shortcut registration failed: %@", hotKeyService.statusMessage)
        }

        let voiceHotKeyService = VoiceHotKeyService()
        self.voiceHotKeyService = voiceHotKeyService
        let voiceRegistered = voiceHotKeyService.register { [weak naturalActionController] in
            naturalActionController?.showCommandWindow(autoStartVoice: true)
        }
        if !voiceRegistered {
            NSLog("DeskPet: voice shortcut registration failed")
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        panelController?.persistCurrentPosition()
        ambientMonitor.stop()
        hotKeyService?.unregister()
        voiceHotKeyService?.unregister()
    }
}
