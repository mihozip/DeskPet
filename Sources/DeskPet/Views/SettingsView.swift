import AppKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: SettingsViewModel
    @ObservedObject private var hotKeyService: GlobalHotKeyService
    @ObservedObject private var actionService: CalendarActionService
    @ObservedObject private var ambientMonitor: GASTaskAmbientMonitor
    @ObservedObject private var preferences: DailyUsePreferencesStore
    @ObservedObject private var launchAtLogin: LaunchAtLoginService
    @ObservedObject private var softwareUpdate: SoftwareUpdateService
    @ObservedObject private var diagnostics: SelfDiagnosticsService

    init(model: SettingsViewModel) {
        self.model = model
        hotKeyService = model.hotKeyService
        actionService = model.actionService
        ambientMonitor = model.ambientMonitor
        preferences = model.dailyPreferences
        launchAtLogin = model.launchAtLogin
        softwareUpdate = model.softwareUpdate
        diagnostics = model.diagnostics
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            sectionPicker
                .padding(.horizontal, 22)
                .padding(.vertical, 14)
            Divider()

            ScrollView {
                Group {
                    switch model.selectedSection {
                    case .general:
                        generalSection
                    case .ai:
                        aiSection
                    case .integrations:
                        integrationsSection
                    case .diagnostics:
                        diagnosticsSection
                    }
                }
                .padding(22)
            }
        }
        .frame(minWidth: 700, minHeight: 650)
        .onAppear {
            model.refreshApplePermissions()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            model.refreshApplePermissions()
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "cat.fill")
                .font(.system(size: 24))
            VStack(alignment: .leading, spacing: 3) {
                Text("DeskPet \(softwareUpdate.currentVersion)")
                    .font(.title2.bold())
                Text("\(model.gasConfiguration.workbenchTitle) — 可更新、可嫁接、可自訂介面名稱與行政職稱。")
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(22)
    }

    private var sectionPicker: some View {
        Picker("設定區域", selection: $model.selectedSection) {
            ForEach(SettingsViewModel.Section.allCases) { section in
                Text(section.title).tag(section)
            }
        }
        .pickerStyle(.segmented)
        .onChange(of: model.selectedSection) { section in
            if section == .diagnostics { diagnostics.refresh() }
        }
    }

    private var generalSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            settingsCard("桌寵與啟動", systemImage: "desktopcomputer") {
                Toggle(
                    "登入後自動啟動 DeskPet",
                    isOn: Binding(
                        get: { launchAtLogin.isEnabled },
                        set: { model.setLaunchAtLogin($0) }
                    )
                )

                Text(launchAtLogin.statusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack {
                    Text("桌寵大小")
                        .frame(width: 110, alignment: .leading)
                    Picker("桌寵大小", selection: $preferences.petSize) {
                        ForEach(DailyUsePreferencesStore.PetSizePreset.allCases) { preset in
                            Text(preset.title).tag(preset)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 330)
                    Spacer()
                }

                HStack {
                    Text("動畫強度")
                        .frame(width: 110, alignment: .leading)
                    Picker("動畫強度", selection: $preferences.animationIntensity) {
                        ForEach(DailyUsePreferencesStore.AnimationIntensity.allCases) { intensity in
                            Text(intensity.title).tag(intensity)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 330)
                    Spacer()
                }

                Text("「安靜」會降低移動幅度與畫面更新頻率，適合整天開著；「活潑」保留完整動畫效果。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            settingsCard("行政職稱與工作介面", systemImage: "person.text.rectangle") {
                HStack {
                    Text("行政職稱")
                        .frame(width: 90, alignment: .leading)
                    TextField("例如：教務主任、事務組長", text: $model.administrativeTitleDraft)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { model.saveAdministrativeTitle() }
                    Button("儲存職稱") { model.saveAdministrativeTitle() }
                    Button("跟隨 Dashboard") { model.resetAdministrativeTitle() }
                        .disabled(model.gasConfiguration.administrativeTitleOverride.isEmpty)
                }

                Text(model.administrativeTitleStatus)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("依序使用本機覆寫、Dashboard ROLE_NAME、預設「總務」。同一職稱會套用到工作台、工作摘要、工作提醒、任務操作與 DeskPet 新建任務的負責人；不修改 Dashboard 的 OFFICE_KEY／ROLE_KEY。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            settingsCard("軟體更新", systemImage: "arrow.triangle.2.circlepath") {
                HStack {
                    Text("目前版本")
                    Text(softwareUpdate.currentVersion)
                        .font(.callout.monospacedDigit().weight(.medium))
                    Spacer()
                    Button(softwareUpdate.isChecking ? "檢查中…" : "檢查更新") {
                        model.checkForUpdates()
                    }
                    .disabled(softwareUpdate.isChecking || softwareUpdate.isInstalling)

                    if softwareUpdate.availableVersion != nil {
                        Button(softwareUpdate.isInstalling ? "更新中…" : "安裝更新") {
                            model.installAvailableUpdate()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!softwareUpdate.canInstall)
                    }
                }

                if softwareUpdate.isInstalling {
                    VStack(alignment: .leading, spacing: 6) {
                        ProgressView(value: softwareUpdate.installProgress, total: 1)
                            .progressViewStyle(.linear)

                        HStack {
                            Text(softwareUpdate.installStage)
                            Spacer()
                            Text("\(softwareUpdate.installPercentage)%")
                                .monospacedDigit()
                        }
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("DeskPet 更新進度")
                    .accessibilityValue("\(softwareUpdate.installPercentage)%：\(softwareUpdate.installStage)")
                }

                Text(softwareUpdate.statusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Text("下載與建置期間會顯示進度；到「準備替換 App」才會自動關閉並重新開啟 DeskPet。失敗時保留或恢復原本的 App。更新紀錄位於 ~/Library/Logs/DeskPet/update.log。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            settingsCard("快速記事快捷鍵", systemImage: "keyboard") {
                Picker("快捷鍵", selection: $model.selectedShortcutID) {
                    ForEach(model.shortcutPresets) { preset in
                        Text(preset.symbolLabel).tag(preset.id)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: model.selectedShortcutID) { _ in model.applyShortcutSelection() }

                Text("目前：\(hotKeyService.activeShortcutPlainLabel)（\(hotKeyService.activeShortcutLabel)）")
                    .font(.callout.weight(.medium))

                statusLine(ok: hotKeyService.isRegistered, text: hotKeyService.statusMessage)

                HStack {
                    Button("測試快速記事") { model.testCapture() }
                    Button("重新註冊") { model.retryRegistration() }
                }
            }

            settingsCard("語音操作", systemImage: "mic.fill") {
                Text("Control + Option + V（⌃⌥V）")
                    .font(.callout.weight(.medium))
                Text("語音只負責捕捉；轉成文字後仍會進 Gemini／本機理解、變更預覽與人工確認。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var aiSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            settingsCard("Gemini", systemImage: "sparkles") {
                Toggle(
                    "啟用 AI 分析",
                    isOn: Binding(
                        get: { model.aiEnabled },
                        set: { model.aiEnabled = $0; model.applyAIEnabled() }
                    )
                )

                Picker(
                    "模型",
                    selection: Binding(
                        get: { model.selectedModelID },
                        set: { model.selectedModelID = $0; model.applyModelSelection() }
                    )
                ) {
                    ForEach(model.aiModelOptions) { option in
                        Text(option.name).tag(option.id)
                    }
                }

                SecureField("Gemini API Key（Google AI Studio）", text: $model.apiKeyDraft)
                    .textFieldStyle(.roundedBorder)

                HStack {
                    Button("儲存 API Key") { model.saveAPIKey() }
                    Button("清除 API Key") { model.clearAPIKey() }.disabled(!model.hasAPIKey)
                    Button(model.isTestingAI ? "測試中…" : "測試 AI") { model.testAI() }
                        .disabled(model.isTestingAI || !model.hasAPIKey)
                }

                statusLine(ok: model.hasAPIKey, text: model.aiStatusMessage)

                Text("API Key 只存在 macOS Keychain。診斷報告只會顯示「是否存在」，不會輸出 Key 本文。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var integrationsSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            settingsCard("Apple Action Layer", systemImage: "calendar.badge.plus") {
                calendarPermissionRow

                if let error = actionService.calendarErrorText {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                }

                remindersPermissionRow

                if let error = actionService.remindersErrorText {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack {
                    Button("重新檢查權限") { model.refreshApplePermissions() }
                    Spacer()
                }

                Text("權限顯示只採用 macOS EventKit 回報的真實狀態。行事曆與提醒事項分開授權；行事曆因支援既有行程查詢需要完整存取。若曾按過「不允許」，macOS 不會再次跳出同一授權視窗，請從系統設定重新開啟。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            settingsCard("校務任務系統（Google Apps Script）", systemImage: "briefcase.fill") {
                Toggle(
                    "啟用校務任務系統串接",
                    isOn: Binding(
                        get: { model.gasEnabled },
                        set: { model.gasEnabled = $0; model.applyGASEnabled() }
                    )
                )

                TextField("GAS Gateway /exec 網址", text: $model.gasEndpoint)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { model.saveGASEndpoint() }

                SecureField("DeskPet API Token", text: $model.gasTokenDraft)
                    .textFieldStyle(.roundedBorder)

                HStack {
                    Button("儲存網址") { model.saveGASEndpoint() }
                    Button("儲存 Token") { model.saveGASToken() }
                    Button("清除 Token") { model.clearGASToken() }.disabled(!model.hasGASToken)
                    Button(model.isTestingGAS ? "測試中…" : "測試連線") { model.testGASConnection() }
                        .disabled(model.isTestingGAS || !model.hasGASToken)
                }

                gasStatusLine

                if let summary = model.gasIntegrationSummary {
                    Text(summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Toggle(
                    "啟用 Ambient Agent 主動任務摘要",
                    isOn: Binding(
                        get: { model.ambientEnabled },
                        set: { model.ambientEnabled = $0; model.applyAmbientEnabled() }
                    )
                )

                HStack {
                    Picker(
                        "同步頻率",
                        selection: Binding(
                            get: { model.ambientIntervalMinutes },
                            set: { model.ambientIntervalMinutes = $0; model.applyAmbientInterval() }
                        )
                    ) {
                        Text("10 分鐘").tag(10)
                        Text("15 分鐘").tag(15)
                        Text("30 分鐘").tag(30)
                        Text("60 分鐘").tag(60)
                    }
                    .frame(width: 240)

                    Spacer()
                    Button(ambientMonitor.isRefreshing ? "同步中…" : "立即同步") {
                        model.refreshAmbientNow()
                    }
                    .disabled(ambientMonitor.isRefreshing || !model.hasGASToken)
                }

                statusLine(ok: ambientMonitor.isMonitoring, text: ambientMonitor.statusMessage)
                Text("主動讀取可以自動；修改、完成、延期仍需人工確認。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var calendarPermissionRow: some View {
        HStack {
            Label("行事曆", systemImage: "calendar").frame(width: 100, alignment: .leading)
            Text(actionService.calendarStatusText).foregroundStyle(.secondary)
            Spacer()

            switch actionService.calendarPermissionState {
            case .fullAccess, .legacyAuthorized:
                Label("可使用", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            case .denied:
                Button("開啟系統設定") { model.openSystemPrivacySettings() }
            case .restricted:
                Text("無法變更").foregroundStyle(.secondary)
            case .writeOnly:
                Button(model.isRequestingCalendar ? "要求中…" : "升級完整存取") { model.requestCalendarAccess() }
                    .disabled(model.isRequestingCalendar || model.isRequestingReminders)
            case .notDetermined, .unknown:
                Button(model.isRequestingCalendar ? "要求中…" : "要求權限") { model.requestCalendarAccess() }
                    .disabled(model.isRequestingCalendar || model.isRequestingReminders)
            }
        }
    }

    private var remindersPermissionRow: some View {
        HStack {
            Label("提醒事項", systemImage: "checklist").frame(width: 100, alignment: .leading)
            Text(actionService.remindersStatusText).foregroundStyle(.secondary)
            Spacer()

            switch actionService.remindersPermissionState {
            case .fullAccess, .legacyAuthorized:
                Label("可使用", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            case .denied:
                Button("開啟系統設定") { model.openSystemPrivacySettings() }
            case .restricted:
                Text("無法變更").foregroundStyle(.secondary)
            case .notDetermined, .writeOnly, .unknown:
                Button(model.isRequestingReminders ? "要求中…" : "要求權限") { model.requestRemindersAccess() }
                    .disabled(model.isRequestingCalendar || model.isRequestingReminders)
            }
        }
    }

    private var diagnosticsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("系統診斷")
                        .font(.title3.bold())
                    Text("只檢查狀態，不顯示 Keychain 中的秘密值。")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("重新檢查") { diagnostics.refresh() }
                Button("複製診斷報告") { diagnostics.copyReport() }
            }

            ForEach(diagnostics.items) { item in
                HStack(alignment: .top, spacing: 12) {
                    diagnosticIcon(item.level)
                        .padding(.top, 2)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(item.title)
                            .font(.callout.bold())
                        Text(item.detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                    Spacer()
                }
                .padding(12)
                .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 10))
            }

            Text("診斷時間：\(diagnostics.generatedAt.formatted(date: .abbreviated, time: .standard))")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var gasStatusLine: some View {
        let ok = model.gasConnectionSucceeded == true || (model.gasConnectionSucceeded == nil && model.hasGASToken)
        return statusLine(ok: ok, text: model.gasStatusMessage)
    }

    private func settingsCard<Content: View>(
        _ title: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: systemImage)
                .font(.headline)
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 12))
    }

    private func statusLine(ok: Bool, text: String) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(ok ? Color.green : Color.orange)
                .frame(width: 8, height: 8)
            Text(text)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func diagnosticIcon(_ level: DiagnosticItem.Level) -> some View {
        let icon: String
        let color: Color
        switch level {
        case .ok:
            icon = "checkmark.circle.fill"
            color = .green
        case .warning:
            icon = "exclamationmark.triangle.fill"
            color = .orange
        case .error:
            icon = "xmark.octagon.fill"
            color = .red
        }
        return Image(systemName: icon)
            .foregroundStyle(color)
    }
}
