import Combine
import Foundation

@MainActor
final class SettingsViewModel: ObservableObject {
    enum Section: String, CaseIterable, Identifiable {
        case general
        case ai
        case integrations
        case diagnostics

        var id: String { rawValue }

        var title: String {
            switch self {
            case .general: return "一般"
            case .ai: return "AI"
            case .integrations: return "整合"
            case .diagnostics: return "診斷"
            }
        }
    }

    @Published var selectedSection: Section = .general
    @Published var selectedShortcutID: String
    @Published var aiEnabled: Bool
    @Published var selectedModelID: String
    @Published var apiKeyDraft: String = ""
    @Published private(set) var aiStatusMessage: String
    @Published private(set) var isTestingAI = false
    @Published private(set) var isRequestingCalendar = false
    @Published private(set) var isRequestingReminders = false

    @Published var gasEnabled: Bool
    @Published var gasEndpoint: String
    @Published var gasTokenDraft: String = ""
    @Published private(set) var gasStatusMessage: String
    @Published private(set) var isTestingGAS = false
    @Published private(set) var gasConnectionSucceeded: Bool? = nil
    @Published var ambientEnabled: Bool
    @Published var ambientIntervalMinutes: Int
    @Published var administrativeTitleDraft: String
    @Published private(set) var administrativeTitleStatus: String

    let hotKeyService: GlobalHotKeyService
    let aiConfiguration: AIConfigurationStore
    let actionService: CalendarActionService
    let gasConfiguration: GASTaskConfigurationStore
    let gasConnector: GASTaskConnector
    let ambientMonitor: GASTaskAmbientMonitor
    let dailyPreferences: DailyUsePreferencesStore
    let launchAtLogin: LaunchAtLoginService
    let softwareUpdate: SoftwareUpdateService
    let diagnostics: SelfDiagnosticsService

    init(
        hotKeyService: GlobalHotKeyService,
        aiConfiguration: AIConfigurationStore,
        actionService: CalendarActionService,
        gasConfiguration: GASTaskConfigurationStore,
        gasConnector: GASTaskConnector,
        ambientMonitor: GASTaskAmbientMonitor,
        dailyPreferences: DailyUsePreferencesStore,
        launchAtLogin: LaunchAtLoginService,
        softwareUpdate: SoftwareUpdateService,
        diagnostics: SelfDiagnosticsService
    ) {
        self.hotKeyService = hotKeyService
        self.aiConfiguration = aiConfiguration
        self.actionService = actionService
        self.gasConfiguration = gasConfiguration
        self.gasConnector = gasConnector
        self.ambientMonitor = ambientMonitor
        self.dailyPreferences = dailyPreferences
        self.launchAtLogin = launchAtLogin
        self.softwareUpdate = softwareUpdate
        self.diagnostics = diagnostics

        selectedShortcutID = hotKeyService.selectedPresetID
        aiEnabled = aiConfiguration.isEnabled
        selectedModelID = aiConfiguration.modelID
        aiStatusMessage = aiConfiguration.statusMessage
        gasEnabled = gasConfiguration.isEnabled
        gasEndpoint = gasConfiguration.endpoint
        gasStatusMessage = gasConfiguration.statusMessage
        ambientEnabled = gasConfiguration.ambientEnabled
        ambientIntervalMinutes = gasConfiguration.ambientIntervalMinutes
        administrativeTitleDraft = gasConfiguration.administrativeTitle
        administrativeTitleStatus = gasConfiguration.administrativeTitleOverride.isEmpty
            ? "目前跟隨 Dashboard 行政職稱"
            : "目前使用 DeskPet 本機覆寫"
    }

    var shortcutPresets: [GlobalHotKeyService.ShortcutPreset] { hotKeyService.availablePresets }
    var aiModelOptions: [AIConfigurationStore.ModelOption] { AIConfigurationStore.modelOptions }
    var hasAPIKey: Bool { aiConfiguration.hasAPIKey }
    var hasGASToken: Bool { gasConfiguration.hasAPIToken }
    var gasIntegrationSummary: String? {
        guard let metadata = gasConfiguration.integrationMetadata else { return nil }
        let name = metadata.displayName.isEmpty ? metadata.systemName : metadata.displayName
        return "已嫁接：\(name)｜\(metadata.categories.count) 個任務類型"
    }

    func showSection(_ section: Section) {
        selectedSection = section
        if section == .diagnostics {
            diagnostics.refresh()
        }
    }

    func applyShortcutSelection() { _ = hotKeyService.selectPreset(id: selectedShortcutID) }
    func retryRegistration() { _ = hotKeyService.reRegister() }
    func testCapture() { hotKeyService.triggerForTesting() }

    func setLaunchAtLogin(_ enabled: Bool) {
        launchAtLogin.setEnabled(enabled)
    }

    func checkForUpdates() {
        Task { await softwareUpdate.checkForUpdates() }
    }

    func installAvailableUpdate() {
        softwareUpdate.installAvailableUpdate()
    }

    func applyAIEnabled() {
        aiConfiguration.isEnabled = aiEnabled
        aiStatusMessage = aiConfiguration.statusMessage
    }

    func applyModelSelection() {
        aiConfiguration.modelID = selectedModelID
        selectedModelID = aiConfiguration.modelID
    }

    func saveAPIKey() {
        do {
            try aiConfiguration.saveAPIKey(apiKeyDraft)
            apiKeyDraft = ""
            aiStatusMessage = aiConfiguration.statusMessage
            objectWillChange.send()
        } catch {
            aiStatusMessage = error.localizedDescription
        }
    }

    func clearAPIKey() {
        do {
            try aiConfiguration.clearAPIKey()
            apiKeyDraft = ""
            aiStatusMessage = aiConfiguration.statusMessage
            objectWillChange.send()
        } catch {
            aiStatusMessage = error.localizedDescription
        }
    }

    func testAI() {
        guard !isTestingAI else { return }
        isTestingAI = true
        aiStatusMessage = "正在測試 AI…"
        let interpreter = GeminiIntentInterpreter(configuration: aiConfiguration)
        Task {
            defer { isTestingAI = false }
            do {
                let result = try await interpreter.interpret(text: "明天下午三點提醒我聯絡廠商")
                aiStatusMessage = "AI 測試成功：\(result.kind.rawValue)｜\(result.title)"
            } catch {
                aiStatusMessage = "AI 測試失敗：\(error.localizedDescription)"
            }
        }
    }

    func requestCalendarAccess() {
        guard !isRequestingCalendar else { return }
        isRequestingCalendar = true
        Task {
            _ = await actionService.requestCalendarAccess()
            isRequestingCalendar = false
        }
    }

    func requestRemindersAccess() {
        guard !isRequestingReminders else { return }
        isRequestingReminders = true
        Task {
            _ = await actionService.requestRemindersAccess()
            isRequestingReminders = false
        }
    }

    func applyGASEnabled() {
        gasConfiguration.isEnabled = gasEnabled
        gasStatusMessage = gasConfiguration.statusMessage
        ambientEnabled = gasConfiguration.ambientEnabled
        ambientIntervalMinutes = gasConfiguration.ambientIntervalMinutes
        ambientMonitor.reconfigure()
    }

    func saveAdministrativeTitle() {
        do {
            try gasConfiguration.saveAdministrativeTitle(administrativeTitleDraft)
            administrativeTitleDraft = gasConfiguration.administrativeTitle
            administrativeTitleStatus = gasConfiguration.administrativeTitleOverride.isEmpty
                ? "已恢復跟隨 Dashboard 行政職稱"
                : "行政職稱已儲存；DeskPet 新建任務會使用此負責人名稱"
        } catch {
            administrativeTitleStatus = error.localizedDescription
        }
    }

    func resetAdministrativeTitle() {
        gasConfiguration.clearAdministrativeTitleOverride()
        administrativeTitleDraft = gasConfiguration.administrativeTitle
        administrativeTitleStatus = "已恢復跟隨 Dashboard 行政職稱"
    }

    func saveGASEndpoint() {
        gasConfiguration.endpoint = gasEndpoint
        gasEndpoint = gasConfiguration.endpoint
        gasStatusMessage = gasConfiguration.endpointURL == nil
            ? "Web App 網址格式無效；必須是 https://"
            : "校務任務系統 Gateway 網址已儲存"
        ambientMonitor.reconfigure()
    }

    func saveGASToken() {
        do {
            try gasConfiguration.saveAPIToken(gasTokenDraft)
            gasTokenDraft = ""
            gasStatusMessage = gasConfiguration.statusMessage
            ambientMonitor.reconfigure()
            objectWillChange.send()
        } catch {
            gasStatusMessage = error.localizedDescription
        }
    }

    func clearGASToken() {
        do {
            try gasConfiguration.clearAPIToken()
            gasTokenDraft = ""
            gasStatusMessage = gasConfiguration.statusMessage
            ambientMonitor.reconfigure()
            objectWillChange.send()
        } catch {
            gasStatusMessage = error.localizedDescription
        }
    }

    func testGASConnection() {
        guard !isTestingGAS else { return }
        saveGASEndpoint()
        gasConfiguration.isEnabled = gasEnabled
        isTestingGAS = true
        gasConnectionSucceeded = nil
        gasStatusMessage = "正在測試校務任務系統…"
        Task {
            defer { isTestingGAS = false }
            do {
                gasStatusMessage = try await gasConnector.testConnection()
                gasConnectionSucceeded = true
                if gasConfiguration.administrativeTitleOverride.isEmpty {
                    administrativeTitleDraft = gasConfiguration.administrativeTitle
                    administrativeTitleStatus = "目前跟隨 Dashboard 行政職稱"
                }
                ambientMonitor.reconfigure()
            } catch {
                gasConnectionSucceeded = false
                gasStatusMessage = "連線失敗：\(error.localizedDescription)"
            }
        }
    }

    func applyAmbientEnabled() {
        gasConfiguration.ambientEnabled = ambientEnabled
        ambientMonitor.reconfigure()
    }

    func applyAmbientInterval() {
        gasConfiguration.ambientIntervalMinutes = ambientIntervalMinutes
        ambientIntervalMinutes = gasConfiguration.ambientIntervalMinutes
        ambientMonitor.reconfigure()
    }

    func refreshAmbientNow() {
        Task { await ambientMonitor.refresh(manual: true) }
    }
}
