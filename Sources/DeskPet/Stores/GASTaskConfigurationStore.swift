import Combine
import Foundation

@MainActor
final class GASTaskConfigurationStore: ObservableObject {
    private enum DefaultsKey {
        static let enabled = "DeskPet.gas.enabled.v1"
        static let endpoint = "DeskPet.gas.endpoint.v1"
        static let ambientEnabled = "DeskPet.gas.ambient.enabled.v1"
        static let ambientIntervalMinutes = "DeskPet.gas.ambient.intervalMinutes.v1"
    }

    private enum KeychainKey {
        static let apiToken = "gas-task-api-token"
    }

    static let defaultEndpoint = ""

    @Published private(set) var hasAPIToken = false
    @Published private(set) var statusMessage = "尚未設定總務工作台 API Token"

    var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: DefaultsKey.enabled) }
        set {
            UserDefaults.standard.set(newValue, forKey: DefaultsKey.enabled)
            objectWillChange.send()
        }
    }

    var endpoint: String {
        get {
            let value = UserDefaults.standard.string(forKey: DefaultsKey.endpoint)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return value?.isEmpty == false ? value! : Self.defaultEndpoint
        }
        set {
            UserDefaults.standard.set(newValue.trimmingCharacters(in: .whitespacesAndNewlines), forKey: DefaultsKey.endpoint)
            objectWillChange.send()
        }
    }

    var endpointURL: URL? {
        guard let url = URL(string: endpoint),
              url.scheme?.lowercased() == "https" else { return nil }
        return url
    }

    var canUseConnector: Bool {
        isEnabled && hasAPIToken && endpointURL != nil
    }

    var ambientEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: DefaultsKey.ambientEnabled) == nil { return true }
            return UserDefaults.standard.bool(forKey: DefaultsKey.ambientEnabled)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: DefaultsKey.ambientEnabled)
            objectWillChange.send()
        }
    }

    var ambientIntervalMinutes: Int {
        get {
            let value = UserDefaults.standard.integer(forKey: DefaultsKey.ambientIntervalMinutes)
            return [10, 15, 30, 60].contains(value) ? value : 15
        }
        set {
            let safe = [10, 15, 30, 60].contains(newValue) ? newValue : 15
            UserDefaults.standard.set(safe, forKey: DefaultsKey.ambientIntervalMinutes)
            objectWillChange.send()
        }
    }

    private let keychain = KeychainService(service: Bundle.main.bundleIdentifier ?? "DeskPet")

    init() {
        refreshTokenStatus()
    }

    func apiToken() throws -> String? {
        try keychain.read(account: KeychainKey.apiToken)
    }

    func saveAPIToken(_ rawValue: String) throws {
        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else {
            try clearAPIToken()
            return
        }
        try keychain.write(value, account: KeychainKey.apiToken)
        refreshTokenStatus(successMessage: "總務工作台 API Token 已安全儲存在 macOS Keychain")
    }

    func clearAPIToken() throws {
        try keychain.delete(account: KeychainKey.apiToken)
        hasAPIToken = false
        statusMessage = "尚未設定總務工作台 API Token"
    }

    func refreshTokenStatus(successMessage: String? = nil) {
        do {
            hasAPIToken = try apiToken()?.isEmpty == false
            statusMessage = hasAPIToken
                ? (successMessage ?? "總務工作台 API Token 已設定")
                : "尚未設定總務工作台 API Token"
        } catch {
            hasAPIToken = false
            statusMessage = error.localizedDescription
        }
    }
}
