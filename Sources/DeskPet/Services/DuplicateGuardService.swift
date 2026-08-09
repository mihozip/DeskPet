import Foundation

struct DuplicateGuardService {
    private let warningThreshold = 0.68

    func findCandidates(
        currentItemID: UUID,
        title: String,
        originalText: String,
        category: String,
        inboxItems: [CaptureItem],
        remoteTasks: [GASTaskDigest.Task]
    ) -> [DuplicateCandidate] {
        var candidates: [DuplicateCandidate] = []
        let currentTexts = [title, originalText].filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

        for item in inboxItems where item.id != currentItemID && item.status == .inbox {
            let candidateTitle = item.interpretation?.title ?? item.linkedGASTaskTitle ?? item.text
            let candidateTexts = [candidateTitle, item.text]
            let score = bestSimilarity(lhs: currentTexts, rhs: candidateTexts)
            guard score >= warningThreshold else { continue }

            let linkedTask: GASTaskDigest.Task? = nil
            candidates.append(
                DuplicateCandidate(
                    id: "inbox:\(item.id.uuidString)",
                    source: .inbox,
                    title: candidateTitle,
                    detail: item.text,
                    similarity: score,
                    inboxItemID: item.id,
                    task: linkedTask
                )
            )
        }

        for task in remoteTasks {
            let candidateTexts = [task.name, task.nextAction ?? "", task.progress ?? ""]
            var score = bestSimilarity(lhs: currentTexts, rhs: candidateTexts)
            if let taskCategory = task.category,
               !category.isEmpty,
               taskCategory == category {
                score = min(1.0, score + 0.04)
            }
            guard score >= warningThreshold else { continue }

            candidates.append(
                DuplicateCandidate(
                    id: "gas:\(task.taskId)",
                    source: .gas,
                    title: task.name,
                    detail: task.nextAction,
                    similarity: score,
                    inboxItemID: nil,
                    task: task
                )
            )
        }

        // 同一個 GAS task 若也從 converted Inbox 被掃到，只保留 GAS 候選。
        let gasTaskIDs = Set(candidates.compactMap { $0.taskID })
        let filtered = candidates.filter { candidate in
            guard candidate.source == .inbox,
                  let inboxID = candidate.inboxItemID,
                  let item = inboxItems.first(where: { $0.id == inboxID }),
                  let linkedID = item.linkedGASTaskID else {
                return true
            }
            return !gasTaskIDs.contains(linkedID)
        }

        return filtered
            .sorted { lhs, rhs in
                if lhs.similarity == rhs.similarity {
                    return lhs.source == .gas && rhs.source != .gas
                }
                return lhs.similarity > rhs.similarity
            }
            .prefix(5)
            .map { $0 }
    }

    private func bestSimilarity(lhs: [String], rhs: [String]) -> Double {
        var best = 0.0
        for left in lhs {
            for right in rhs {
                best = max(best, similarity(left, right))
            }
        }
        return best
    }

    private func similarity(_ lhs: String, _ rhs: String) -> Double {
        let left = normalize(lhs)
        let right = normalize(rhs)
        guard !left.isEmpty, !right.isEmpty else { return 0 }
        if left == right { return 1.0 }
        if left.count >= 5, right.contains(left) { return 0.94 }
        if right.count >= 5, left.contains(right) { return 0.94 }

        let leftBigrams = bigrams(left)
        let rightBigrams = bigrams(right)
        guard !leftBigrams.isEmpty, !rightBigrams.isEmpty else {
            return left == right ? 1.0 : 0.0
        }
        let intersection = leftBigrams.intersection(rightBigrams).count
        let dice = (2.0 * Double(intersection)) / Double(leftBigrams.count + rightBigrams.count)

        let leftChars = Set(left)
        let rightChars = Set(right)
        let charIntersection = leftChars.intersection(rightChars).count
        let charUnion = leftChars.union(rightChars).count
        let jaccard = charUnion == 0 ? 0.0 : Double(charIntersection) / Double(charUnion)

        return min(1.0, dice * 0.72 + jaccard * 0.28)
    }

    private func normalize(_ text: String) -> String {
        let lowered = text.lowercased()
        let scalars = lowered.unicodeScalars.filter { scalar in
            CharacterSet.alphanumerics.contains(scalar) ||
            (scalar.value >= 0x4E00 && scalar.value <= 0x9FFF)
        }
        return String(String.UnicodeScalarView(scalars))
    }

    private func bigrams(_ text: String) -> Set<String> {
        let chars = Array(text)
        guard chars.count >= 2 else { return Set([text]) }
        var result = Set<String>()
        for index in 0..<(chars.count - 1) {
            result.insert(String([chars[index], chars[index + 1]]))
        }
        return result
    }
}
