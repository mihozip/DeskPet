import Combine
import Foundation

@MainActor
final class GASTaskConfigurationStore: ObservableObject {
    private enum DefaultsKey {
        static let enabled = "DeskPet.gas.enabled.v1"
        static let endpoint = "DeskPet.gas.endpoint.v1"
        static let ambientEnabled = "DeskPet.gas.ambient.enabled.v1"
        static let ambientIntervalMinutes = "DeskPet.gas.ambient.intervalMinutes.v1"
        static let integrationMetadata = "DeskPet.gas.integrationMetadata.v1"
        static let administrativeTitleOverride = "DeskPet.gas.administrativeTitleOverride.v1"
        static let workRoleName = "DeskPet.interface.workRoleName.v1"
    }

    private enum KeychainKey {
        static let apiToken = "gas-task-api-token"
    }

    static let defaultEndpoint = ""
    static let defaultWorkRoleName = "總務"

    @Published private(set) var hasAPIToken = false
    @Published private(set) var statusMessage = "尚未設定校務任務系統 API Token"
    @Published private(set) var integrationMetadata: GASTaskIntegrationMetadata?
    @Published private(set) var administrativeTitleOverride: String
    @Published private(set) var workRoleName: String

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
            let normalized = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if normalized != endpoint {
                clearIntegrationMetadata()
            }
            UserDefaults.standard.set(normalized, forKey: DefaultsKey.endpoint)
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

    var categories: [String] {
        nonempty(integrationMetadata?.categories) ?? GASTaskTaxonomy.categories
    }

    var priorities: [String] {
        nonempty(integrationMetadata?.priorities) ?? GASTaskTaxonomy.priorities
    }

    var defaultCategory: String {
        categories.contains("其他") ? "其他" : (categories.first ?? "其他")
    }

    var administrativeTitle: String {
        administrativeTitleOverride.isEmpty
            ? (integrationMetadata?.roleName ?? "")
            : administrativeTitleOverride
    }

    var workbenchTitle: String { "\(workRoleName)工作台" }
    var taskDigestTitle: String { "\(workRoleName)工作摘要" }
    var taskActionTitle: String { "\(workRoleName)任務操作" }
    var reminderTitle: String { "\(workRoleName)提醒" }

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
        administrativeTitleOverride = UserDefaults.standard
            .string(forKey: DefaultsKey.administrativeTitleOverride) ?? ""
        let savedRoleName = UserDefaults.standard
            .string(forKey: DefaultsKey.workRoleName)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        workRoleName = savedRoleName.isEmpty ? Self.defaultWorkRoleName : savedRoleName
        if let data = UserDefaults.standard.data(forKey: DefaultsKey.integrationMetadata) {
            integrationMetadata = try? JSONDecoder().decode(GASTaskIntegrationMetadata.self, from: data)
        }
        refreshTokenStatus()
    }

    func applyIntegrationMetadata(_ metadata: GASTaskIntegrationMetadata) {
        integrationMetadata = metadata
        if let data = try? JSONEncoder().encode(metadata) {
            UserDefaults.standard.set(data, forKey: DefaultsKey.integrationMetadata)
        }
    }

    func clearIntegrationMetadata() {
        integrationMetadata = nil
        UserDefaults.standard.removeObject(forKey: DefaultsKey.integrationMetadata)
    }

    func saveAdministrativeTitle(_ rawValue: String) throws {
        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard value.count <= 40,
              value.unicodeScalars.allSatisfy({ !CharacterSet.controlCharacters.contains($0) }) else {
            throw ConfigurationError.invalidAdministrativeTitle
        }
        administrativeTitleOverride = value
        if value.isEmpty {
            UserDefaults.standard.removeObject(forKey: DefaultsKey.administrativeTitleOverride)
        } else {
            UserDefaults.standard.set(value, forKey: DefaultsKey.administrativeTitleOverride)
        }
    }

    func clearAdministrativeTitleOverride() {
        administrativeTitleOverride = ""
        UserDefaults.standard.removeObject(forKey: DefaultsKey.administrativeTitleOverride)
    }

    func saveWorkRoleName(_ rawValue: String) throws {
        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty,
              value.count <= 20,
              value.unicodeScalars.allSatisfy({ !CharacterSet.controlCharacters.contains($0) }) else {
            throw ConfigurationError.invalidWorkRoleName
        }
        workRoleName = value
        UserDefaults.standard.set(value, forKey: DefaultsKey.workRoleName)
    }

    func resetWorkRoleName() {
        workRoleName = Self.defaultWorkRoleName
        UserDefaults.standard.removeObject(forKey: DefaultsKey.workRoleName)
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
        refreshTokenStatus(successMessage: "校務任務系統 API Token 已安全儲存在 macOS Keychain")
    }

    func clearAPIToken() throws {
        try keychain.delete(account: KeychainKey.apiToken)
        hasAPIToken = false
        statusMessage = "尚未設定校務任務系統 API Token"
    }

    func refreshTokenStatus(successMessage: String? = nil) {
        do {
            hasAPIToken = try apiToken()?.isEmpty == false
            statusMessage = hasAPIToken
                ? (successMessage ?? "校務任務系統 API Token 已設定")
                : "尚未設定校務任務系統 API Token"
        } catch {
            hasAPIToken = false
            statusMessage = error.localizedDescription
        }
    }

    private func nonempty(_ values: [String]?) -> [String]? {
        guard let values, !values.isEmpty else { return nil }
        return values
    }

    private enum ConfigurationError: LocalizedError {
        case invalidAdministrativeTitle
        case invalidWorkRoleName

        var errorDescription: String? {
            switch self {
            case .invalidAdministrativeTitle:
                return "行政職稱不可超過 40 個字，也不可包含控制字元。"
            case .invalidWorkRoleName:
                return "介面角色名稱不可留白、不可超過 20 個字，也不可包含控制字元。"
            }
        }
    }
}
