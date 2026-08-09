import Foundation

struct GASTaskIntegrationMetadata: Codable, Equatable {
    let schema: String
    let systemName: String
    let schoolName: String
    let officeKey: String
    let officeName: String
    let roleKey: String
    let roleName: String
    let categories: [String]
    let statuses: [String]
    let priorities: [String]
    let boardDisplayOptions: [String]

    var displayName: String {
        [schoolName, officeName, roleName]
            .filter { !$0.isEmpty }
            .joined(separator: "｜")
    }
}

enum GASTaskTaxonomy {
    static let categories = ["修繕", "採購", "財產", "場地", "午餐", "工程", "防災", "文書", "會議", "其他"]
    static let priorities = ["高", "中", "低"]

    static func inferredCategory(from text: String) -> String {
        let rules: [(String, [String])] = [
            ("修繕", ["修繕", "維修", "修理", "故障", "漏水", "水電"]),
            ("採購", ["採購", "報價", "估價", "比價", "招標", "決標", "標案", "採買"]),
            ("財產", ["財產", "盤點", "財物", "報廢", "移撥"]),
            ("場地", ["場地", "借用", "活動中心", "操場", "教室使用"]),
            ("午餐", ["午餐", "供餐", "食材", "廚房"]),
            ("工程", ["工程", "施工", "驗收", "開工", "竣工"]),
            ("防災", ["防災", "消防", "避難", "演練", "災害"]),
            ("文書", ["公文", "函", "簽辦", "核銷", "文書"]),
            ("會議", ["會議", "開會", "小組會議", "會報"])
        ]

        for (category, keywords) in rules where keywords.contains(where: { text.localizedCaseInsensitiveContains($0) }) {
            return category
        }
        return "其他"
    }

    static func inferredPriority(from text: String) -> String {
        if ["緊急", "急件", "立刻", "立即", "今天一定", "今天前"].contains(where: { text.contains($0) }) {
            return "高"
        }
        if ["不急", "有空", "之後再"].contains(where: { text.contains($0) }) {
            return "低"
        }
        return "中"
    }
}
