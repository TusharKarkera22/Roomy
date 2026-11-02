import CryptoKit
import Foundation

public struct DuplicateGroup: Identifiable, Sendable {
    public let id = UUID()
    public let size: Int64
    public var files: [URL]
    /// Space freed by keeping one copy and trashing the rest.
    public var wasted: Int64 { size * Int64(files.count - 1) }
}

// ponytail: hard links and APFS clones show up as duplicates though they share space; check inode/clone IDs if that misleads people.
public enum Duplicates {
    /// Files of at least `minSize` bytes under `folder` with identical contents, biggest waste first.
    /// Skips hidden files and the insides of packages (Photos libraries, apps), where removing one file breaks the whole.
    public static func find(in folder: URL, minSize: Int64 = 1_000_000) -> [DuplicateGroup] {
        let keys: Set<URLResourceKey> = [.fileSizeKey, .isRegularFileKey]
        guard let walker = FileManager.default.enumerator(at: folder, includingPropertiesForKeys: Array(keys), options: [.skipsHiddenFiles, .skipsPackageDescendants], errorHandler: { _, _ in true }) else { return [] }

        var bySize: [Int64: [URL]] = [:]
        for case let url as URL in walker {
            guard let values = try? url.resourceValues(forKeys: keys), values.isRegularFile == true,
                  let size = values.fileSize, size >= minSize else { continue }
            bySize[Int64(size), default: []].append(url)
        }

        var groups: [DuplicateGroup] = []
        for (size, sameSize) in bySize where sameSize.count > 1 {
            for (hash, same) in Dictionary(grouping: sameSize, by: hash) where hash != nil && same.count > 1 {
                groups.append(DuplicateGroup(size: size, files: same.sorted { $0.path < $1.path }))
            }
        }
        return groups.sorted { $0.wasted > $1.wasted }
    }

    /// SHA-256 of the whole file, or nil if any part can't be read (so a partial read never looks like a match).
    static func hash(_ url: URL) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        var hasher = SHA256()
        do {
            while let chunk = try handle.read(upToCount: 1 << 20), !chunk.isEmpty { hasher.update(data: chunk) }
        } catch { return nil }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}
