import AppKit
import RoomyCore
import SwiftUI

func bytes(_ count: Int64) -> String {
    ByteCountFormatter.string(fromByteCount: count, countStyle: .file)
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
