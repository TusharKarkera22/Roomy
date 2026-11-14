import AppKit
import RoomyCore
import SwiftUI

func bytes(_ count: Int64) -> String {
    ByteCountFormatter.string(fromByteCount: count, countStyle: .file)
}

/// The startup disk's size and the space free on it.
func startupDisk() -> (total: Int64, free: Int64) {
    let values = try? URL(filePath: "/").resourceValues(forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey])
    return (Int64(values?.volumeTotalCapacity ?? 0), values?.volumeAvailableCapacityForImportantUsage ?? 0)
}

/// The startup disk split into what a home folder scan can explain: the home folder, apps, and everything else macOS keeps.
struct DiskBreakdown {
    let total: Int64
    let free: Int64
    let home: Int64
    let apps: Int64
    /// macOS itself, swap, and system files: whatever is in use outside the home folder and Applications.
    var system: Int64 { total - free - home - apps }
}

/// The path with the home folder shown as `~`.
func tildePath(_ url: URL) -> String {
    let home = URL.homeDirectory.path
    return url.path.hasPrefix(home) ? "~" + url.path.dropFirst(home.count) : url.path
}

/// Shortens text for dot-matrix headings, which can't truncate themselves.
func clip(_ text: String, _ limit: Int) -> String {
    text.count > limit ? text.prefix(limit - 2) + ".." : text
}

func reveal(_ url: URL) {
    NSWorkspace.shared.activateFileViewerSelecting([url])
}

func chooseFolder() -> URL? {
    let panel = NSOpenPanel()
    panel.canChooseDirectories = true
    panel.canChooseFiles = false
    return panel.runModal() == .OK ? panel.url : nil
}
