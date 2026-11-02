import AppKit
import Observation
import RoomyCore

enum Screen {
    case welcome, access, scanning, report, explore, duplicates
}

struct Toast: Identifiable {
    let id = UUID()
    let text: String
    var isError = false
    var offersTrash = false
}

/// A cleanup waiting for the user to confirm it.
enum CleanAction {
    /// Move this item to the Trash.
    case trash(Node)
    /// A Safe folder Roomy keeps (like ~/Library/Caches): move what's inside to the Trash.
    case trashContents(Node)
    /// The Trash itself: ask Finder to empty it for good.
    case emptyTrash(Node)

    var node: Node {
        switch self {
        case .trash(let node), .trashContents(let node), .emptyTrash(let node): node
        }
    }

    var buttonTitle: String {
        switch self {
        case .trash: "Move to Trash…"
        case .trashContents: "Trash contents…"
        case .emptyTrash: "Empty Trash…"
        }
    }
}

struct ScanResult {
    let tree: Node
    let files: Int
    let seconds: Double
    let stoppedEarly: Bool
}

@MainActor @Observable
final class AppModel {
    var screen: Screen = UserDefaults.standard.bool(forKey: "onboarded") ? .scanning : .welcome
    private(set) var root: URL = .homeDirectory
    private(set) var result: ScanResult?
    private(set) var progress = ScanProgress()
    var current: Node?
    var selected: Node?
    private(set) var suggestions: [Suggestion] = []
    private(set) var locked: [Node] = []
    /// Bumped whenever the tree changes, so views showing sizes redraw.
    private(set) var revision = 0
    var toast: Toast?
    var pending: CleanAction?
    let knowledge = Result { try KnowledgeBase.bundled() }
    @ObservationIgnored private var cache: [URL: ScanResult] = [:]

    func start() {
        // For development: `Roomy --scan <folder> [--explore]` skips the welcome screen and scans that folder.
        let arguments = CommandLine.arguments
        if let flag = arguments.firstIndex(of: "--scan"), flag + 1 < arguments.count {
            Task {
                await scan(URL(filePath: arguments[flag + 1]), fresh: true)
                if arguments.contains("--explore") { screen = .explore }
            }
            return
        }
        if screen == .scanning { Task { await scan(.homeDirectory, fresh: true) } }
    }

    func rule(for node: Node) -> Rule? {
        if case .success(let knowledge) = knowledge { knowledge.explain(node.path) } else { nil }
    }

    // MARK: Scanning

    func scan(_ url: URL, fresh: Bool = false) async {
        progress.cancel()
        root = url
        if !fresh, let cached = cache[url] { return show(cached) }

        let progress = ScanProgress()
        self.progress = progress
        screen = .scanning
        let started = Date()
        let tree = await DiskScanner.scan(url, progress: progress)
        // A newer scan replaced this one while it ran.
        guard progress === self.progress else { return }

        let result = ScanResult(tree: tree, files: progress.snapshot.files, seconds: Date().timeIntervalSince(started), stoppedEarly: progress.isCancelled)
        if !result.stoppedEarly { cache[url] = result }
        show(result)
    }

    func stopScan() { progress.cancel() }

    private func show(_ result: ScanResult) {
        self.result = result
        current = result.tree
        selected = nil
        refreshSummary()
        screen = .report
    }

    private func refreshSummary() {
        guard let tree = result?.tree else { return }
        if case .success(let knowledge) = knowledge { suggestions = knowledge.suggestions(in: tree) }
        locked = tree.lockedFolders()
        revision += 1
    }

    // MARK: Browsing

    /// Shows the item selected inside its folder.
    func goTo(_ node: Node) {
        current = node.parent ?? node
        selected = node
        screen = .explore
    }

    func enter(_ folder: Node) {
        current = folder
        selected = nil
    }

    // MARK: Cleaning

    /// What cleaning this item means, or nil if Roomy won't touch it.
    func cleanAction(for node: Node) -> CleanAction? {
        guard !node.isLocked, !node.isOtherDisk else { return nil }
        if node.isDirectory && node.path == URL.homeDirectory.appending(path: ".Trash").path { return .emptyTrash(node) }
        if canTrash(node) { return .trash(node) }
        if node.isDirectory && rule(for: node)?.verdict == .safe { return .trashContents(node) }
        return nil
    }

    func confirmPending() {
        guard let action = pending else { return }
        pending = nil
        switch action {
        case .trash(let node):
            do {
                try Safety.trash(node.url)
            } catch {
                toast = Toast(text: error.localizedDescription, isError: true)
                return
            }
            node.detach()
            if selected === node { selected = nil }
            refreshSummary()
            toast = Toast(text: "Moved “\(node.name)” (\(bytes(node.size))) to the Trash. Empty the Trash to actually free the space.", offersTrash: true)

        case .trashContents(let node):
            Task {
                let outcome = Safety.trashContents(of: node.url)
                let freed = await rescan(node)
                var text = "Moved \(outcome.moved) items from “\(node.name)” to the Trash (\(bytes(freed))). Empty the Trash to actually free the space."
                if outcome.failed > 0 { text += " \(outcome.failed) were in use by open apps and stayed." }
                toast = Toast(text: text, isError: outcome.moved == 0 && outcome.failed > 0, offersTrash: outcome.moved > 0)
            }

        case .emptyTrash(let node):
            Task {
                guard await Self.askFinderToEmptyTrash() else {
                    toast = Toast(text: "Finder didn't empty the Trash. If macOS asked whether Roomy may control Finder, allow it in System Settings › Privacy & Security › Automation.", isError: true)
                    return
                }
                let freed = await rescan(node)
                toast = Toast(text: "Emptied the Trash. \(bytes(freed)) is free again.")
            }
        }
    }

    /// Measures a folder again after cleaning it and updates the tree. Returns how much smaller it got.
    private func rescan(_ node: Node) async -> Int64 {
        let before = node.size
        node.adopt(await DiskScanner.scan(node.url, progress: ScanProgress()))
        refreshSummary()
        return max(0, before - node.size)
    }

    /// Finder empties the Trash properly, including locked items and the Trash folders on other disks.
    private static func askFinderToEmptyTrash() async -> Bool {
        await withCheckedContinuation { continuation in
            let finder = Process()
            finder.executableURL = URL(filePath: "/usr/bin/osascript")
            finder.arguments = ["-e", "tell application \"Finder\" to empty trash"]
            finder.terminationHandler = { continuation.resume(returning: $0.terminationStatus == 0) }
            do { try finder.run() } catch { continuation.resume(returning: false) }
        }
    }

    // MARK: Full Disk Access

    /// macOS only lets apps with Full Disk Access open the privacy database, so trying to read it is the standard check.
    static var hasFullDiskAccess: Bool {
        (try? FileHandle(forReadingFrom: .homeDirectory.appending(path: "Library/Application Support/com.apple.TCC/TCC.db"))) != nil
    }

    /// Opens the Full Disk Access list and shows Roomy in Finder, ready to drag into it.
    func openFullDiskAccessSettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_AllFiles")!)
        NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL])
    }

    /// macOS applies Full Disk Access when an app starts, so Roomy reopens itself.
    func relaunch() {
        let reopen = Process()
        reopen.executableURL = URL(filePath: "/bin/sh")
        reopen.arguments = ["-c", "sleep 1; open \"$0\"", Bundle.main.bundleURL.path]
        try? reopen.run()
        NSApp.terminate(nil)
    }

    func finishOnboarding() {
        UserDefaults.standard.set(true, forKey: "onboarded")
        Task { await scan(.homeDirectory, fresh: true) }
    }
}
