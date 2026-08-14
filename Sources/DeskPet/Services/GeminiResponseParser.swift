import Foundation

enum GeminiResponseParser {
    struct TextPart: Decodable {
        let text: String?
        let thought: Bool?
    }

    enum ParseError: LocalizedError {
        case missingAnswer
        case malformedJSON(String)

        var errorDescription: String? {
            switch self {
            case .missingAnswer:
                return "Gemini 沒有回傳可解析的最終答案"
            case .malformedJSON(let detail):
                return "Gemini 結構化回應格式錯誤：\(detail)"
            }
        }
    }

    static func finalAnswerText(from parts: [TextPart]) -> String? {
        let fragments = parts.compactMap { part -> String? in
            guard part.thought != true,
                  let text = part.text?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !text.isEmpty else {
                return nil
            }
            return text
        }

        guard !fragments.isEmpty else { return nil }
        return fragments.joined(separator: "\n")
    }

    static func decodeStructuredOutput<T: Decodable>(_ type: T.Type, from text: String) throws -> T {
        let cleaned = stripMarkdownFence(from: text)
        guard let data = cleaned.data(using: .utf8) else {
            throw ParseError.malformedJSON("回應不是有效的 UTF-8 文字")
        }

        do {
            return try JSONDecoder().decode(type, from: data)
        } catch let error as DecodingError {
            throw ParseError.malformedJSON(decodingDescription(error))
        } catch {
            throw ParseError.malformedJSON(error.localizedDescription)
        }
    }

    private static func stripMarkdownFence(from text: String) -> String {
        var cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleaned.hasPrefix("```") else { return cleaned }

        if let firstNewline = cleaned.firstIndex(of: "\n") {
            cleaned = String(cleaned[cleaned.index(after: firstNewline)...])
        }

        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasSuffix("```") {
            cleaned.removeLast(3)
        }
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func decodingDescription(_ error: DecodingError) -> String {
        switch error {
        case .keyNotFound(let key, let context):
            return "缺少欄位 \(path(context.codingPath, appending: key))"
        case .typeMismatch(_, let context):
            return "欄位型別不符：\(path(context.codingPath))"
        case .valueNotFound(_, let context):
            return "欄位缺少必要值：\(path(context.codingPath))"
        case .dataCorrupted(let context):
            return "JSON 資料損壞：\(context.debugDescription)"
        @unknown default:
            return "未知的 JSON 解碼錯誤"
        }
    }

    private static func path(_ codingPath: [CodingKey], appending key: CodingKey? = nil) -> String {
        let keys = codingPath.map(\.stringValue) + (key.map { [$0.stringValue] } ?? [])
        return keys.isEmpty ? "<root>" : keys.joined(separator: ".")
    }
}
