import Foundation

struct CaptureItem: Identifiable, Codable, Equatable {
    let id: UUID
    let text: String
    let createdAt: Date
    var status: Status
    var interpretation: SmartInterpretation?
    var actionReceipts: [ActionReceipt]
    var linkedGASTaskID: String?
    var linkedGASTaskTitle: String?
    var linkedGASTaskURL: String?
    var convertedAt: Date?

    enum Status: String, Codable {
        case inbox
        case converted
        case done
    }

    var isConvertedToGASTask: Bool {
        linkedGASTaskID?.isEmpty == false
    }

    init(
        id: UUID = UUID(),
        text: String,
        createdAt: Date = Date(),
        status: Status = .inbox,
        interpretation: SmartInterpretation? = nil,
        actionReceipts: [ActionReceipt] = [],
        linkedGASTaskID: String? = nil,
        linkedGASTaskTitle: String? = nil,
        linkedGASTaskURL: String? = nil,
        convertedAt: Date? = nil
    ) {
        self.id = id
        self.text = text
        self.createdAt = createdAt
        self.status = status
        self.interpretation = interpretation
        self.actionReceipts = actionReceipts
        self.linkedGASTaskID = linkedGASTaskID
        self.linkedGASTaskTitle = linkedGASTaskTitle
        self.linkedGASTaskURL = linkedGASTaskURL
        self.convertedAt = convertedAt
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case text
        case createdAt
        case status
        case interpretation
        case actionReceipts
        case actionReceipt // 0.4.x 舊版單一 receipt，相容讀取
        case linkedGASTaskID
        case linkedGASTaskTitle
        case linkedGASTaskURL
        case convertedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        text = try container.decode(String.self, forKey: .text)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        status = try container.decode(Status.self, forKey: .status)
        interpretation = try container.decodeIfPresent(SmartInterpretation.self, forKey: .interpretation)

        if let receipts = try container.decodeIfPresent([ActionReceipt].self, forKey: .actionReceipts) {
            actionReceipts = receipts
        } else if let legacyReceipt = try container.decodeIfPresent(ActionReceipt.self, forKey: .actionReceipt) {
            actionReceipts = [legacyReceipt]
        } else {
            actionReceipts = []
        }

        let gasReceipt = actionReceipts.first(where: { $0.kind == .gasTask })
        linkedGASTaskID = try container.decodeIfPresent(String.self, forKey: .linkedGASTaskID)
            ?? gasReceipt?.externalIdentifier
        linkedGASTaskTitle = try container.decodeIfPresent(String.self, forKey: .linkedGASTaskTitle)
            ?? gasReceipt?.title
        linkedGASTaskURL = try container.decodeIfPresent(String.self, forKey: .linkedGASTaskURL)
            ?? gasReceipt?.externalURL
        convertedAt = try container.decodeIfPresent(Date.self, forKey: .convertedAt)
            ?? gasReceipt?.createdAt

        // 0.9.1 以前已經送進 GAS 的舊 Inbox，在第一次讀取時自動升級為「已轉任務」。
        if status == .inbox, linkedGASTaskID?.isEmpty == false {
            status = .converted
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(text, forKey: .text)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(status, forKey: .status)
        try container.encodeIfPresent(interpretation, forKey: .interpretation)
        try container.encode(actionReceipts, forKey: .actionReceipts)
        try container.encodeIfPresent(linkedGASTaskID, forKey: .linkedGASTaskID)
        try container.encodeIfPresent(linkedGASTaskTitle, forKey: .linkedGASTaskTitle)
        try container.encodeIfPresent(linkedGASTaskURL, forKey: .linkedGASTaskURL)
        try container.encodeIfPresent(convertedAt, forKey: .convertedAt)
    }
}
