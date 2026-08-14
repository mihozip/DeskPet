import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let workEventStore = WorkEventStore()
    private lazy var store = CaptureStore(workEventStore: workEventStore)
    private let aiConfiguration = AIConfigurationStore()
    private let actionService = CalendarActionService()
    private let calendarQueryService = CalendarQueryService()
    private let gasConfiguration = GASTaskConfigurationStore()
    private let dailyPreferences = DailyUsePreferencesStore()
    private let snoozeStore = SnoozeStore()
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
    private var calendarQueryWindowController: CalendarQueryWindowController?
    private var statusMenuController: StatusMenuController?
    private var hotKeyService: GlobalHotKeyService?
    private var voiceHotKeyService: VoiceHotKeyService?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let localInterpreter = LocalIntentInterpreter()
        let aiInterpreter = GeminiIntentInterpreter(configuration: aiConfiguration)

        let interactionController = TaskInteractionWindowController(
            connector: gasConnector,
            gasConfiguration: gasConfiguration,
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
            onOpenInteraction: { [weak interactionController] task, action, note, dueDate, nextAction in
                interactionController?.show(
                    task: task,
                    preselectedAction: action,
                    prefilledNote: note,
                    prefilledDueDate: dueDate,
                    prefilledNextAction: nextAction
                )
            }
        )
        naturalTaskCommandWindowController = naturalActionController

        let digestController = TaskDigestWindowController(
            monitor: ambientMonitor,
            gasConfiguration: gasConfiguration,
            captureStore: store,
            workEventStore: workEventStore,
            snoozeStore: snoozeStore,
            onOpenTaskAction: { [weak interactionController] task, action in
                interactionController?.show(task: task, preselectedAction: action)
            },
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

                    digestController?.showDigest()
                }
            }
        )
        inboxWindowController = inboxController

        let diaryController = WorkDiaryWindowController(store: workEventStore)
        workDiaryWindowController = diaryController

        let calendarQueryController = CalendarQueryWindowController(service: calendarQueryService)
        calendarQueryWindowController = calendarQueryController

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

        softwareUpdate.onUpdateAvailable = { [weak self, weak settingsController] version in
            guard let self else { return }

            NSApp.activate(ignoringOtherApps: true)
            let alert = NSAlert()
            alert.alertStyle = .informational
            alert.messageText = "白帥帥有新版本"
            alert.informativeText = "DeskPet \(version) 已可更新。目前版本為 \(self.softwareUpdate.currentVersion)。"
            alert.addButton(withTitle: "立即更新")
            alert.addButton(withTitle: "稍後")

            if alert.runModal() == .alertFirstButtonReturn {
                settingsController?.showSettings()
                self.softwareUpdate.installAvailableUpdate()
            }
        }

        let panelController = PetPanelController(
            store: store,
            ambientMonitor: ambientMonitor,
            dailyPreferences: dailyPreferences,
            gasConfiguration: gasConfiguration,
            workEventStore: workEventStore,
            snoozeStore: snoozeStore,
            onOpenInbox: { [weak inboxController] in inboxController?.showInbox() },
            onOpenTaskDigest: { [weak digestController] in digestController?.showDigest() },
            onOpenDiary: { [weak diaryController] in diaryController?.showDiary() },
            onOpenCalendarQuery: { [weak calendarQueryController] in calendarQueryController?.showCalendarQuery() },
            onOpenNaturalAction: { [weak naturalActionController] in naturalActionController?.showCommandWindow() },
            onOpenVoiceAction: { [weak naturalActionController] in naturalActionController?.showCommandWindow(autoStartVoice: true) },
            onOpenSettings: { [weak settingsController] in settingsController?.showSettings() },
            onOpenDiagnostics: { [weak settingsController] in settingsController?.showDiagnostics() },
            shortcutLabel: { [weak hotKeyService] in hotKeyService?.activeShortcutLabel ?? "快捷鍵" }
        )
        self.panelController = panelController
        panelController.show()

        statusMenuController = StatusMenuController(
            gasConfiguration: gasConfiguration,
            onQuickCapture: { [weak panelController] in panelController?.showCapture() },
            onOpenInbox: { [weak inboxController] in inboxController?.showInbox() },
            onOpenTaskDigest: { [weak digestController] in digestController?.showDigest() },
            onOpenCalendarQuery: { [weak calendarQueryController] in calendarQueryController?.showCalendarQuery() },
            onOpenSettings: { [weak settingsController] in settingsController?.showSettings() }
        )

        ambientMonitor.start()
        softwareUpdate.startAutomaticChecking()

        let registered = hotKeyService.register { [weak panelController] in panelController?.showCapture() }
        if !registered {
            NSLog("DeskPet: global shortcut registration failed: %@", hotKeyService.statusMessage)
        }

        let voiceHotKeyService = VoiceHotKeyService()
        self.voiceHotKeyService = voiceHotKeyService
        let voiceRegistered = voiceHotKeyService.register { [weak naturalActionController, weak self] in
            guard self?.gasConfiguration.isLinked == true else { return }
            naturalActionController?.showCommandWindow(autoStartVoice: true)
        }
        if !voiceRegistered {
            NSLog("DeskPet: voice shortcut registration failed")
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        panelController?.persistCurrentPosition()
        ambientMonitor.stop()
        softwareUpdate.stopAutomaticChecking()
        hotKeyService?.unregister()
        voiceHotKeyService?.unregister()
    }
}
