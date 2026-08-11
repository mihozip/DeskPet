import Foundation

@MainActor
protocol GASTaskUpdating {
    func updateTask(
        taskId: String,
        status: String?,
        dueDate: String?,
        dueTime: String?,
        nextAction: String?,
        waitingFor: String?,
        progress: String?,
        reason: String
    ) async throws -> GASTaskDigest.Task
}

@MainActor
final class GASTaskConnector: GASTaskUpdating {
    struct RemoteTask: Decodable {
        let taskId: String
        let name: String
        let category: String?
        let status: String?
        let priority: String?
        let dueDate: String?
        let dueTime: String?
        let nextAction: String?
        let waitingFor: String?
        let progress: String?
        let detailUrl: String?
        let createdAt: String?
        let updatedAt: String?
    }

    enum ConnectorError: LocalizedError {
        case disabled
        case missingToken
        case invalidEndpoint
        case invalidResponse
        case httpStatus(Int)
        case api(String)

        var errorDescription: String? {
            switch self {
            case .disabled:
                return "請先在設定中啟用校務任務系統串接"
            case .missingToken:
                return "請先設定校務任務系統 API Token"
            case .invalidEndpoint:
                return "校務任務系統 Gateway 網址無效"
            case .invalidResponse:
                return "校務任務系統回傳格式無法辨識"
            case .httpStatus(let code):
                if code == 401 || code == 403 {
                    return "Google Web App 在進入 DeskPet API 前拒絕請求（HTTP \(code)）。請改用獨立 DeskPet API Gateway，並將 Gateway 部署為『執行身分：我／存取：任何人』。"
                }
                return "校務任務系統連線失敗（HTTP \(code)）"
            case .api(let message):
                return message
            }
        }
    }

    private struct APIRequest: Encodable {
        let apiVersion: String
        let action: String
        let token: String
        let clientTaskId: String?
        let source: String?
        let rawText: String?
        let task: TaskPayload?
        let limit: Int?
        let taskId: String?
        let update: TaskUpdatePayload?
        let reason: String?
    }

    private struct TaskPayload: Encodable {
        let name: String
        let category: String
        let status: String
        let priority: String
        let dueDate: String
        let dueTime: String
        let nextAction: String
        let owner: String
        let boardDisplay: String
        let sortOrder: Int
    }


    private struct TaskUpdatePayload: Encodable {
        let status: String?
        let dueDate: String?
        let dueTime: String?
        let nextAction: String?
        let waitingFor: String?
        let progress: String?
    }

    private struct APIResponse: Decodable {
        let ok: Bool
        let message: String?
        let created: Bool?
        let duplicate: Bool?
        let task: RemoteTask?
        let error: APIErrorPayload?
        let summary: GASTaskDigest.Summary?
        let tasks: [GASTaskDigest.Task]?
        let serverTime: String?
        let integration: GASTaskIntegrationMetadata?
    }

    private struct APIErrorPayload: Decodable {
        let code: String?
        let message: String?
    }

    private let configuration: GASTaskConfigurationStore
    private let session: URLSession

    init(configuration: GASTaskConfigurationStore, session: URLSession = .shared) {
        self.configuration = configuration
        self.session = session
    }

    func testConnection() async throws -> String {
        let response = try await send(
            APIRequest(
                apiVersion: "3",
                action: "ping",
                token: try resolvedToken(),
                clientTaskId: nil,
                source: "deskpet-macos",
                rawText: nil,
                task: nil,
                limit: nil,
                taskId: nil,
                update: nil,
                reason: nil
            )
        )
        return response.message ?? "校務任務系統 API 連線成功"
    }

    func fetchTaskDigest(limit: Int = 12) async throws -> GASTaskDigest {
        let response = try await send(
            APIRequest(
                apiVersion: "3",
                action: "taskDigest",
                token: try resolvedToken(),
                clientTaskId: nil,
                source: "deskpet-macos",
                rawText: nil,
                task: nil,
                limit: max(1, min(limit, 30)),
                taskId: nil,
                update: nil,
                reason: nil
            )
        )

        guard let summary = response.summary, let tasks = response.tasks else {
            throw ConnectorError.invalidResponse
        }

        return GASTaskDigest(summary: summary, tasks: tasks, serverTime: response.serverTime)
    }

    func createTask(
        clientTaskID: UUID,
        title: String,
        originalText: String,
        category: String,
        priority: String,
        dueDate: Date?
    ) async throws -> ActionReceipt {
        let formatter = Self.taipeiDateFormatter
        let timeFormatter = Self.taipeiTimeFormatter

        let payload = TaskPayload(
            name: title,
            category: configuration.categories.contains(category) ? category : configuration.defaultCategory,
            status: "未開始",
            priority: configuration.priorities.contains(priority) ? priority : (configuration.priorities.first ?? "中"),
            dueDate: dueDate.map(formatter.string(from:)) ?? "",
            dueTime: dueDate.map(timeFormatter.string(from:)) ?? "",
            nextAction: originalText,
            owner: configuration.administrativeTitle,
            boardDisplay: "自動",
            sortOrder: 9999
        )

        let response = try await send(
            APIRequest(
                apiVersion: "3",
                action: "createTask",
                token: try resolvedToken(),
                clientTaskId: clientTaskID.uuidString,
                source: "deskpet-macos",
                rawText: originalText,
                task: payload,
                limit: nil,
                taskId: nil,
                update: nil,
                reason: nil
            )
        )

        guard let task = response.task else {
            throw ConnectorError.invalidResponse
        }

        return ActionReceipt(
            kind: .gasTask,
            externalIdentifier: task.taskId,
            externalURL: task.detailUrl,
            title: task.name,
            createdAt: Date()
        )
    }

    func updateTask(
        taskId: String,
        status: String?,
        dueDate: String?,
        dueTime: String?,
        nextAction: String?,
        waitingFor: String?,
        progress: String?,
        reason: String
    ) async throws -> GASTaskDigest.Task {
        let response = try await send(
            APIRequest(
                apiVersion: "3",
                action: "updateTask",
                token: try resolvedToken(),
                clientTaskId: nil,
                source: "deskpet-macos",
                rawText: nil,
                task: nil,
                limit: nil,
                taskId: taskId,
                update: TaskUpdatePayload(
                    status: status,
                    dueDate: dueDate,
                    dueTime: dueTime,
                    nextAction: nextAction,
                    waitingFor: waitingFor,
                    progress: progress
                ),
                reason: reason
            )
        )

        guard let remote = response.task else {
            throw ConnectorError.invalidResponse
        }

        return GASTaskDigest.Task(
            taskId: remote.taskId,
            name: remote.name,
            category: remote.category,
            status: remote.status,
            priority: remote.priority,
            dueDate: remote.dueDate,
            dueTime: remote.dueTime,
            nextAction: remote.nextAction,
            waitingFor: remote.waitingFor,
            progress: remote.progress,
            detailUrl: remote.detailUrl,
            flags: nil,
            createdAt: remote.createdAt,
            updatedAt: remote.updatedAt
        )
    }

    private func resolvedToken() throws -> String {
        guard configuration.isEnabled else { throw ConnectorError.disabled }
        guard let token = try configuration.apiToken(), !token.isEmpty else {
            throw ConnectorError.missingToken
        }
        return token
    }

    private func send(_ payload: APIRequest) async throws -> APIResponse {
        guard let endpoint = configuration.endpointURL else {
            throw ConnectorError.invalidEndpoint
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw ConnectorError.invalidResponse
        }
        guard (200...299).contains(http.statusCode) else {
            throw ConnectorError.httpStatus(http.statusCode)
        }

        let decoded: APIResponse
        do {
            decoded = try JSONDecoder().decode(APIResponse.self, from: data)
        } catch {
            if let text = String(data: data, encoding: .utf8), text.contains("<html") || text.contains("<!DOCTYPE") {
                throw ConnectorError.api("Web App 回傳登入／HTML 頁面；請確認 API 部署允許 DeskPet 直接 POST，或改用獨立 API Gateway 部署。")
            }
            throw ConnectorError.invalidResponse
        }

        guard decoded.ok else {
            throw ConnectorError.api(decoded.error?.message ?? decoded.message ?? "校務任務系統 API 回報失敗")
        }
        if let integration = decoded.integration {
            configuration.applyIntegrationMetadata(integration)
        }
        return decoded
    }

    private static let taipeiDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Taipei")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let taipeiTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Taipei")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
}
