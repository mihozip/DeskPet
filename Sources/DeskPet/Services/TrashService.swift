import AppKit
import Darwin
import Foundation

@MainActor
enum TrashService {
    private struct CleanupResult: Sendable {
        var deletedCount = 0
        var scannedDirectories = 0
        var failures: [String] = []
    }

    static func confirmAndEmptyTrash() {
        let alert = NSAlert()
        alert.messageText = "清理垃圾桶？"
        alert.informativeText = "垃圾桶內的項目會被永久刪除，無法復原。DeskPet 會直接清理目前使用者的本機垃圾桶，以及可存取之外接磁碟垃圾桶。"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "清理垃圾桶")
        alert.addButton(withTitle: "取消")

        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        Task {
            let result = await Task.detached(priority: .userInitiated) {
                cleanupTrashDirectories()
            }.value
            showResult(result)
        }
    }

    nonisolated private static func cleanupTrashDirectories() -> CleanupResult {
        let fileManager = FileManager.default
        let directories = trashDirectories(fileManager: fileManager)
        var result = CleanupResult()

        for directory in directories {
            guard fileManager.fileExists(atPath: directory.path) else { continue }
            result.scannedDirectories += 1

            let items: [URL]
            do {
                items = try fileManager.contentsOfDirectory(
                    at: directory,
                    includingPropertiesForKeys: nil,
                    options: []
                )
            } catch {
                result.failures.append("\(displayName(for: directory))：\(error.localizedDescription)")
                continue
            }

            for item in items {
                do {
                    try fileManager.removeItem(at: item)
                    result.deletedCount += 1
                } catch {
                    result.failures.append("\(item.lastPathComponent)：\(error.localizedDescription)")
                }
            }
        }

        return result
    }

    nonisolated private static func trashDirectories(fileManager: FileManager) -> [URL] {
        var directories: [URL] = [
            fileManager.homeDirectoryForCurrentUser.appendingPathComponent(".Trash", isDirectory: true)
        ]

        let userID = String(getuid())
        let resourceKeys: Set<URLResourceKey> = [.volumeIsReadOnlyKey]
        let volumes = fileManager.mountedVolumeURLs(
            includingResourceValuesForKeys: Array(resourceKeys),
            options: [.skipHiddenVolumes]
        ) ?? []

        for volume in volumes {
            guard volume.path != "/" else { continue }
            if let values = try? volume.resourceValues(forKeys: resourceKeys),
               values.volumeIsReadOnly == true {
                continue
            }

            let externalTrash = volume
                .appendingPathComponent(".Trashes", isDirectory: true)
                .appendingPathComponent(userID, isDirectory: true)

            var isDirectory: ObjCBool = false
            if fileManager.fileExists(atPath: externalTrash.path, isDirectory: &isDirectory),
               isDirectory.boolValue {
                directories.append(externalTrash)
            }
        }

        var seen = Set<String>()
        return directories.filter { url in
            let path = url.standardizedFileURL.path
            guard seen.insert(path).inserted else { return false }
            return true
        }
    }

    nonisolated private static func displayName(for directory: URL) -> String {
        if directory.path == FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".Trash", isDirectory: true).path {
            return "本機垃圾桶"
        }
        return directory.deletingLastPathComponent().deletingLastPathComponent().lastPathComponent + " 垃圾桶"
    }

    private static func showResult(_ result: CleanupResult) {
        let alert = NSAlert()
        alert.addButton(withTitle: "好")

        if result.failures.isEmpty {
            if result.deletedCount == 0 {
                alert.messageText = "垃圾桶目前是空的"
                alert.informativeText = "沒有找到需要刪除的項目。"
            } else {
                alert.messageText = "垃圾桶已清理"
                alert.informativeText = "已永久刪除 \(result.deletedCount) 個項目。"
            }
        } else {
            let preview = result.failures.prefix(3).joined(separator: "\n")
            if result.deletedCount > 0 {
                alert.messageText = "垃圾桶已部分清理"
                alert.informativeText = "已刪除 \(result.deletedCount) 個項目，但仍有部分項目無法刪除：\n\n\(preview)"
            } else {
                alert.messageText = "無法清理垃圾桶"
                alert.informativeText = "DeskPet 無法刪除垃圾桶內容：\n\n\(preview)"
            }
            alert.alertStyle = .warning
        }

        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
}
