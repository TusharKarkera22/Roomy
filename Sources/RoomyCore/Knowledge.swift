import Foundation

/// How safe a folder is to delete. `nil` everywhere means Roomy doesn't know the folder.
public enum Verdict: String, Codable, Sendable {
    /// Rebuilt or re-downloaded on its own; nothing of yours is lost.
    case safe
    /// Might hold something you want; read the explanation first.
    case review
    /// Don't move it to the Trash; use `howToClean` instead.
    case keep
}

/// One entry in rules.json: what a folder is and what happens if you delete it.
public struct Rule: Codable, Sendable, Identifiable {
    public let id: String
    /// Shell-style patterns (fnmatch, `*` also matches `/`). A leading `~/` means the home folder.
    public let paths: [String]
    public let title: String
    public let owner: String
    public let what: String
    public let ifDeleted: String
    public let verdict: Verdict
    public let comesBack: Bool
    public let howToClean: String?
    /// Covers a wide area (all of Application Support, all of Documents), so it's never a cleanup suggestion itself.
    public let broad: Bool?

    public var isBroad: Bool { broad ?? false }
}

public struct KnowledgeBase: Sendable {
    public let rules: [Rule]
    private let home: String

    public init(data: Data, home: String = NSHomeDirectory()) throws {
        rules = try JSONDecoder().decode([Rule].self, from: data)
        self.home = home
    }

    /// rules.json from the app bundle, or from the package resources under `swift run` and tests.
    public static func bundled(home: String = NSHomeDirectory()) throws -> KnowledgeBase {
        let url = Bundle.main.url(forResource: "rules", withExtension: "json")
            ?? Bundle.module.url(forResource: "rules", withExtension: "json")!
        return try KnowledgeBase(data: Data(contentsOf: url), home: home)
    }

    /// The first rule with a matching pattern, so specific rules sit above generic ones in rules.json.
    public func explain(_ path: String) -> Rule? {
        rules.first { rule in
            rule.paths.contains { fnmatch(expand($0), path, 0) == 0 }
        }
    }

    private func expand(_ pattern: String) -> String {
        pattern.hasPrefix("~/") ? home + pattern.dropFirst() : pattern
    }
}
