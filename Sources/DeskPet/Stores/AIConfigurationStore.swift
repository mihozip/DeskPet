import Combine
import Foundation

@MainActor
final class AIConfigurationStore: ObservableObject {
    struct ModelOption: Identifiable, Equatable {
        let id: String
        let name: String
    }

    private enum DefaultsKey {
        static let enabled = "DeskPet.ai.enabled.v1"
        static let modelID = "DeskPet.ai.gemini.model.v1"
    }

    private enum KeychainKey {
        static let apiKey = "gemini-api-key"
    }

    /// Prefer the newest stable Flash model currently exposed by the Gemini API.
    static let defaultModelID = "gemini-3.6-flash"

    /// Keep the picker limited to the current Gemini 3.5+ production models that
    /// fit DeskPet's text/structured-output workflows. Gemini 2.x options are
    /// intentionally retired from the UI. No Gemini 3.7 API model is published
    /// by Google at the time of this release, so no speculative model ID is added.
    static let modelOptions: [ModelOption] = [
        ModelOption(id: "gemini-3.6-flash", name: "Gemini 3.6 Flash（最新／建議）"),
        ModelOption(id: "gemini-3.5-flash", name: "Gemini 3.5 Flash（高品質）"),
        ModelOption(id: "gemini-3.5-flash-lite", name: "Gemini 3.5 Flash-Lite（快速／省成本）")
    ]

    @Published private(set) var hasAPIKey = false
    @Published private(set) var statusMessage = "尚未設定 Gemini API Key"

    var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: DefaultsKey.enabled) }
        set {
            UserDefaults.standard.set(newValue, forKey: DefaultsKey.enabled)
            objectWillChange.send()
        }
    }

    var modelID: String {
        get {
            let saved = UserDefaults.standard.string(forKey: DefaultsKey.modelID)
            return Self.modelOptions.contains(where: { $0.id == saved }) ? saved! : Self.defaultModelID
        }
        set {
            let safeValue = Self.modelOptions.contains(where: { $0.id == newValue }) ? newValue : Self.defaultModelID
            UserDefaults.standard.set(safeValue, forKey: DefaultsKey.modelID)
            objectWillChange.send()
        }
    }

    var canUseAI: Bool {
        isEnabled && hasAPIKey
    }

    private let keychain = KeychainService(service: Bundle.main.bundleIdentifier ?? "DeskPet")

    init() {
        migrateRetiredModelSelectionIfNeeded()
        refreshKeyStatus()
    }

    func apiKey() throws -> String? {
        try keychain.read(account: KeychainKey.apiKey)
    }

    func saveAPIKey(_ rawValue: String) throws {
        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else {
            try clearAPIKey()
            return
        }
        try keychain.write(value, account: KeychainKey.apiKey)
        refreshKeyStatus(successMessage: "Gemini API Key 已安全儲存在 macOS Keychain")
    }

    func clearAPIKey() throws {
        try keychain.delete(account: KeychainKey.apiKey)
        hasAPIKey = false
        statusMessage = "尚未設定 Gemini API Key"
    }

    func refreshKeyStatus(successMessage: String? = nil) {
        do {
            hasAPIKey = try apiKey()?.isEmpty == false
            statusMessage = hasAPIKey
                ? (successMessage ?? "Gemini API Key 已設定")
                : "尚未設定 Gemini API Key"
        } catch {
            hasAPIKey = false
            statusMessage = error.localizedDescription
        }
    }

    private func migrateRetiredModelSelectionIfNeeded() {
        guard let saved = UserDefaults.standard.string(forKey: DefaultsKey.modelID),
              !Self.modelOptions.contains(where: { $0.id == saved }) else {
            return
        }
        UserDefaults.standard.set(Self.defaultModelID, forKey: DefaultsKey.modelID)
    }
}
