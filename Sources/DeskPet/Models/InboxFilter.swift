import Foundation

enum InboxFilter: String, CaseIterable, Identifiable {
    case inbox = "待處理"
    case converted = "已轉任務"
    case done = "已完成"
    case all = "全部"

    var id: String { rawValue }
}
