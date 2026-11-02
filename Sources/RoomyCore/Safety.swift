import Foundation

public struct RefusedToTrash: LocalizedError {
    public var errorDescription: String? {
        "Roomy won't move this to the Trash: it's a top-level system or home folder. Open it and remove what's inside instead."
    }
}

/// The only way Roomy removes anything: to the Trash, never a permanent delete.
public enum Safety {
    static let protectedHomeFolders: Set = ["Library", "Documents", "Desktop", "Downloads", "Pictures", "Movies", "Music", "Applications", "Public", ".Trash"]

    public static func canTrash(_ url: URL, home: URL = .homeDirectory) -> Bool {
        let path = url.standardizedFileURL.path
        let home = home.standardizedFileURL.path
        let parent = (path as NSString).deletingLastPathComponent
        if path == "/" || parent == "/" || path == home { return false }
        if path.hasPrefix("/System/") || path.hasPrefix(home + "/.Trash/") { return false }
        if parent == home + "/Library" { return false }
        if parent == home, protectedHomeFolders.contains((path as NSString).lastPathComponent) { return false }
        return true
    }

    public static func trash(_ url: URL) throws {
        guard canTrash(url) else { throw RefusedToTrash() }
        try FileManager.default.trashItem(at: url, resultingItemURL: nil)
    }

    /// Moves everything inside `folder` to the Trash but keeps the folder, for places like ~/Library/Caches
    /// that macOS expects to exist. Items an open app is holding on to stay put and are counted as failed.
    public static func trashContents(of folder: URL) -> (moved: Int, failed: Int) {
        let items = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
        var moved = 0
        for item in items where (try? trash(item)) != nil { moved += 1 }
        return (moved, items.count - moved)
    }
}
