import Foundation
@testable import RoomyCore
import XCTest

final class RoomyCoreTests: XCTestCase {
    let home = "/Users/test"

    func testRulesLoadWithUniqueIDs() throws {
        let rules = try KnowledgeBase.bundled(home: home).rules
        XCTAssertGreaterThan(rules.count, 50)
        XCTAssertEqual(Set(rules.map(\.id)).count, rules.count)
    }

    func testSpecificRulesWinOverGenericOnes() throws {
        let knowledge = try KnowledgeBase.bundled(home: home)
        let cases = [
            "/Users/test/Library/Developer/Xcode/DerivedData": "xcode-derived-data",
            "/Users/test/Library/Application Support/Claude/vm_bundles/claudevm.bundle": "claude-vm",
            "/Users/test/Library/Application Support/Claude": "claude-app",
            "/Users/test/Library/Application Support/Slack/Cache": "electron-cache",
            "/Users/test/Library/Application Support/Google/Chrome/Default/Cache": "electron-cache",
            "/Users/test/Library/Application Support/Google/Chrome/Default": "browser-profile",
            "/Users/test/Library/Application Support/SomeApp": "app-support",
            "/Users/test/Documents/site/node_modules": "node-modules",
            "/Users/test/Documents/site/.git": "git-history",
            "/Users/test/Documents/notes.txt": "personal-files",
            "/Users/test/Downloads/Setup.dmg": "installer-image",
            "/Users/test/.claude/projects": "claude-code-chats",
            "/Users/test/.npm/_cacache": "npm-cache",
            "/Users/test/.gradle/caches": "gradle",
            "/Users/test/.gradle": "build-tool-home",
            "/Users/test/.cache/huggingface": "huggingface",
            "/Users/test/.cache": "dot-cache",
        ]
        for (path, id) in cases {
            XCTAssertEqual(knowledge.explain(path)?.id, id, path)
        }
        XCTAssertNil(knowledge.explain("/Users/test/some-folder"))
    }

    func testTrashGuardBlocksTopLevelFolders() {
        let home = URL(filePath: "/Users/test")
        let blocked = ["/", "/Applications", "/Users/test", "/Users/test/Library", "/Users/test/Library/Caches",
                       "/Users/test/Downloads", "/Users/test/.Trash/old.zip", "/System/Library/Fonts"]
        let allowed = ["/Users/test/Library/Caches/com.example", "/Users/test/.npm", "/Users/test/Downloads/a.dmg"]
        for path in blocked { XCTAssertFalse(Safety.canTrash(URL(filePath: path), home: home), path) }
        for path in allowed { XCTAssertTrue(Safety.canTrash(URL(filePath: path), home: home), path) }
    }

    func testDuplicatesMatchContentNotJustSize() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }

        let content = Data(repeating: 7, count: 2_000_000)
        var different = content
        different[1_999_999] = 8
        try content.write(to: folder.appending(path: "a.bin"))
        try content.write(to: folder.appending(path: "b.bin"))
        try different.write(to: folder.appending(path: "c.bin"))
        try Data(repeating: 1, count: 10).write(to: folder.appending(path: "small1"))
        try Data(repeating: 1, count: 10).write(to: folder.appending(path: "small2"))

        let groups = Duplicates.find(in: folder)
        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups.first?.files.map(\.lastPathComponent), ["a.bin", "b.bin"])
        XCTAssertEqual(groups.first?.wasted, 2_000_000)
    }

    func testScanKeepsBigFilesCountsSmallOnesAndFlagsLockedFolders() async throws {
        let fm = FileManager.default
        let folder = fm.temporaryDirectory.appending(path: UUID().uuidString)
        try fm.createDirectory(at: folder.appending(path: "inner"), withIntermediateDirectories: true)
        try fm.createDirectory(at: folder.appending(path: "locked"), withIntermediateDirectories: true)
        try fm.setAttributes([.posixPermissions: 0], ofItemAtPath: folder.appending(path: "locked").path)
        defer {
            try? fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: folder.appending(path: "locked").path)
            try? fm.removeItem(at: folder)
        }
        try Data(repeating: 1, count: 3_000_000).write(to: folder.appending(path: "big1"))
        try Data(repeating: 2, count: 1_500_000).write(to: folder.appending(path: "inner/big2"))
        try Data(repeating: 3, count: 10_000).write(to: folder.appending(path: "inner/small"))
        try Data(repeating: 4, count: 10).write(to: folder.appending(path: "tiny"))

        let tree = await DiskScanner.scan(folder, progress: ScanProgress())
        XCTAssertEqual(tree.children.first?.name, "big1")
        XCTAssertEqual(Set(tree.children.map(\.name)), ["big1", "inner", "locked"])
        XCTAssertEqual(tree.smallFiles, 1)
        let inner = try XCTUnwrap(tree.children.first { $0.name == "inner" })
        XCTAssertEqual(inner.children.map(\.name), ["big2"])
        XCTAssertEqual(inner.smallFiles, 1)
        XCTAssertEqual(inner.path, folder.path + "/inner")
        XCTAssertEqual(tree.size, tree.smallFilesSize + tree.children.reduce(0) { $0 + $1.size })
        XCTAssertEqual(tree.largestFiles().map(\.name), ["big1", "big2"])
        XCTAssertEqual(tree.lockedFolders().map(\.name), ["locked"])

        let before = tree.size
        let big2 = inner.children[0]
        big2.detach()
        XCTAssertEqual(tree.size, before - big2.size)
        XCTAssertTrue(inner.children.isEmpty)

        // Emptying a folder on disk, then adopting a rescan of it, shrinks the whole tree to match.
        try fm.removeItem(at: folder.appending(path: "inner/big2"))
        try fm.removeItem(at: folder.appending(path: "inner/small"))
        let shrunk = tree.size - inner.size
        inner.adopt(await DiskScanner.scan(folder.appending(path: "inner"), progress: ScanProgress()))
        XCTAssertEqual(inner.size, 0)
        XCTAssertEqual(inner.smallFiles, 0)
        XCTAssertEqual(tree.size, shrunk)
    }

    func testSuggestionsPickTopmostSpecificItems() throws {
        let knowledge = try KnowledgeBase.bundled(home: home)
        let tree = Node(root: URL(filePath: home))
        func folder(_ name: String, in parent: Node, small: Int64 = 0) -> Node {
            let node = Node(name: name, isDirectory: true, parent: parent)
            node.smallFilesSize = small
            parent.children.append(node)
            return node
        }
        let library = folder("Library", in: tree)
        let caches = folder("Caches", in: library)
        let chrome = folder("com.google.Chrome", in: caches, small: 300_000_000)
        let support = folder("Application Support", in: library)
        let someApp = folder("SomeApp", in: support, small: 500_000_000)
        let ollama = folder(".ollama", in: tree, small: 1_000_000_000)
        for node in [chrome, caches, someApp, support, library, ollama, tree] { node.total() }

        let ids = knowledge.suggestions(in: tree).map(\.rule.id)
        XCTAssertEqual(ids, ["ollama", "caches"])
    }
}
