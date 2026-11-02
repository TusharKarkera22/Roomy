import Foundation

/// A folder, or a file of at least `DiskScanner.bigFile` bytes, in a scanned tree.
/// Smaller files are only counted on their folder, which keeps a whole-disk tree small enough to hold in memory.
public final class Node: Identifiable, @unchecked Sendable {
    public let name: String
    public let isDirectory: Bool
    public internal(set) var size: Int64
    /// Largest first.
    public internal(set) var children: [Node] = []
    public internal(set) weak var parent: Node?
    public internal(set) var smallFiles = 0
    public internal(set) var smallFilesSize: Int64 = 0
    /// macOS wouldn't let us list this folder, so its size is unknown.
    public internal(set) var isLocked = false
    /// Another disk or a device mounted here (such as a connected iPhone under ~/Library/Developer), which we don't measure.
    public internal(set) var isOtherDisk = false
    private let rootPath: String?

    init(root: URL) {
        name = root.lastPathComponent
        isDirectory = true
        size = 0
        rootPath = root.path
    }

    init(name: String, isDirectory: Bool, size: Int64 = 0, parent: Node) {
        self.name = name
        self.isDirectory = isDirectory
        self.size = size
        self.parent = parent
        rootPath = nil
    }

    public var path: String { parent.map { $0.path + "/" + name } ?? rootPath! }
    public var url: URL { URL(filePath: path, directoryHint: isDirectory ? .isDirectory : .notDirectory) }

    /// Takes this item out of the tree after it was trashed, shrinking every folder above it.
    public func detach() {
        guard let parent else { return }
        parent.children.removeAll { $0 === self }
        var ancestor: Node? = parent
        while let folder = ancestor {
            folder.size -= size
            ancestor = folder.parent
        }
    }

    /// Takes the contents of a fresh scan of this same folder, shrinking or growing every folder above it to match.
    public func adopt(_ fresh: Node) {
        let change = fresh.size - size
        children = fresh.children
        children.forEach { $0.parent = self }
        smallFiles = fresh.smallFiles
        smallFilesSize = fresh.smallFilesSize
        isLocked = fresh.isLocked
        var folder: Node? = self
        while let current = folder {
            current.size += change
            folder = current.parent
        }
    }

    /// The biggest files anywhere inside this folder.
    public func largestFiles(limit: Int = 200) -> [Node] {
        var files: [Node] = []
        var folders = [self]
        while let folder = folders.popLast() {
            for child in folder.children {
                if child.isDirectory { folders.append(child) } else { files.append(child) }
            }
        }
        return Array(files.sorted { $0.size > $1.size }.prefix(limit))
    }

    /// Folders macOS kept closed during the scan.
    public func lockedFolders() -> [Node] {
        var locked: [Node] = []
        var folders = [self]
        while let folder = folders.popLast() {
            if folder.isLocked { locked.append(folder) }
            folders.append(contentsOf: folder.children.lazy.filter(\.isDirectory))
        }
        return locked
    }

    func total() {
        size = smallFilesSize + children.reduce(0) { $0 + $1.size }
        children.sort { $0.size > $1.size }
    }
}

/// Live counters a scan updates from many threads and the UI reads.
public final class ScanProgress: @unchecked Sendable {
    private let lock = NSLock()
    private var files = 0
    private var bytes: Int64 = 0
    private var folder = ""
    private var stopped = false

    public init() {}

    public var snapshot: (files: Int, bytes: Int64, folder: String) { lock.withLock { (files, bytes, folder) } }
    public var isCancelled: Bool { lock.withLock { stopped } }
    public func cancel() { lock.withLock { stopped = true } }

    func record(files count: Int, bytes size: Int64, folder path: String) {
        lock.withLock {
            files += count
            bytes += size
            folder = path
        }
    }
}

public enum DiskScanner {
    public static let bigFile: Int64 = 1_000_000
    static let keys: Set<URLResourceKey> = [.isDirectoryKey, .isSymbolicLinkKey, .isVolumeKey, .totalFileAllocatedSizeKey]

    /// Measures everything under `root`. Stops early (returning what it has) if `progress` is cancelled.
    public static func scan(_ root: URL, progress: ScanProgress) async -> Node {
        let tree = Node(root: root)
        await fill(tree, at: root, progress: progress, depth: 0)
        return tree
    }

    /// The top levels are read in parallel; deeper folders on the same thread.
    static func fill(_ node: Node, at url: URL, progress: ScanProgress, depth: Int) async {
        let folders = readLevel(node, at: url, progress: progress)
        await withTaskGroup(of: Void.self) { group in
            for (child, childURL) in folders {
                group.addTask {
                    if depth < 2 {
                        await fill(child, at: childURL, progress: progress, depth: depth + 1)
                    } else {
                        fillInPlace(child, at: childURL, progress: progress)
                    }
                }
            }
        }
        node.total()
    }

    static func fillInPlace(_ node: Node, at url: URL, progress: ScanProgress) {
        for (child, childURL) in readLevel(node, at: url, progress: progress) where !progress.isCancelled {
            fillInPlace(child, at: childURL, progress: progress)
        }
        node.total()
    }

    /// Lists one folder: subfolders and big files become children, small files are counted. Returns the subfolders.
    static func readLevel(_ node: Node, at url: URL, progress: ScanProgress) -> [(Node, URL)] {
        guard !progress.isCancelled else { return [] }
        guard let items = try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: Array(keys)) else {
            node.isLocked = true
            return []
        }
        var folders: [(Node, URL)] = []
        var bytes: Int64 = 0
        for item in items {
            let values = try? item.resourceValues(forKeys: keys)
            if values?.isDirectory == true, values?.isSymbolicLink != true {
                let child = Node(name: item.lastPathComponent, isDirectory: true, parent: node)
                node.children.append(child)
                // Reading a mounted device can hang for minutes, so stay on the disk we started on.
                if values?.isVolume == true { child.isOtherDisk = true } else { folders.append((child, item)) }
            } else {
                let size = Int64(values?.totalFileAllocatedSize ?? 0)
                bytes += size
                if size >= bigFile {
                    node.children.append(Node(name: item.lastPathComponent, isDirectory: false, size: size, parent: node))
                } else {
                    node.smallFiles += 1
                    node.smallFilesSize += size
                }
            }
        }
        progress.record(files: items.count - folders.count, bytes: bytes, folder: url.path)
        return folders
    }
}

public struct Suggestion: Identifiable, Sendable {
    public let node: Node
    public let rule: Rule
    public var id: ObjectIdentifier { node.id }
}

extension KnowledgeBase {
    /// The biggest specific things worth cleaning: the topmost item of each Safe rule, or Review rule that isn't broad, of at least `minSize`.
    public func suggestions(in tree: Node, minSize: Int64 = 100_000_000) -> [Suggestion] {
        var found: [Suggestion] = []
        func visit(_ node: Node) {
            // Small items can't hold a big suggestion, which also keeps this fast on a whole-disk tree.
            guard node.size >= minSize else { return }
            if let rule = explain(node.path), rule.verdict == .safe || (rule.verdict == .review && !rule.isBroad) {
                found.append(Suggestion(node: node, rule: rule))
                return
            }
            node.children.forEach(visit)
        }
        visit(tree)
        return found.sorted { $0.node.size > $1.node.size }
    }
}
