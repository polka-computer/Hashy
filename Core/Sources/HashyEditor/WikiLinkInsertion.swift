import Foundation

// MARK: - Wiki-Link Insertion

/// Utilities for inserting and parsing wiki-links in markdown text.
public enum WikiLinkInsertion {

    /// The trigger character/sequence that initiated the embed.
    public enum Trigger {
        case wikiLink   // [[
        case mention    // @

        var suffix: String {
            switch self {
            case .wikiLink: return "[["
            case .mention: return "@"
            }
        }
    }

    /// Insert a wiki-link at the current cursor position (replacing trailing trigger if present).
    /// Returns the new text with the wiki-link inserted.
    public static func insert(
        into text: String,
        objectId: String,
        displayName: String,
        replacingTrigger trigger: Trigger? = .wikiLink
    ) -> String {
        var result = text
        if let trigger, result.hasSuffix(trigger.suffix) {
            result = String(result.dropLast(trigger.suffix.count))
        }
        result += "[[\(objectId)|\(displayName)]]"
        return result
    }

    /// Extract all wiki-links from markdown content.
    /// Returns array of (targetId, displayName?) tuples.
    public static func extractWikiLinks(from content: String) -> [(targetId: String, displayName: String?)] {
        let pattern = #"\[\[([^\]|]+)(?:\|([^\]]+))?\]\]"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }

        let nsContent = content as NSString
        let range = NSRange(location: 0, length: nsContent.length)
        let matches = regex.matches(in: content, range: range)

        return matches.compactMap { match in
            guard match.range(at: 1).location != NSNotFound else { return nil }
            let targetId = nsContent.substring(with: match.range(at: 1))
            var displayName: String?
            if match.range(at: 2).location != NSNotFound {
                displayName = nsContent.substring(with: match.range(at: 2))
            }
            return (targetId: targetId, displayName: displayName)
        }
    }

    /// Check if text ends with the wiki-link trigger `[[`.
    public static func hasWikiLinkTrigger(in text: String) -> Bool {
        text.hasSuffix("[[")
    }

    /// Check if text ends with a mention trigger `@` preceded by whitespace or at start.
    public static func hasMentionTrigger(in text: String) -> Bool {
        guard text.hasSuffix("@") else { return false }
        let beforeAt = text.dropLast()
        return beforeAt.isEmpty || beforeAt.last?.isWhitespace == true || beforeAt.last?.isNewline == true
    }

    /// Detect any embed trigger at end of text.
    public static func detectTrigger(in text: String) -> Trigger? {
        if hasWikiLinkTrigger(in: text) { return .wikiLink }
        if hasMentionTrigger(in: text) { return .mention }
        return nil
    }

    /// Convert a wiki-link token back to its canonical form for storage.
    /// Input: the attributed representation
    /// Output: `[[id|title]]` string
    public static func canonicalize(targetId: String, displayName: String) -> String {
        "[[\(targetId)|\(displayName)]]"
    }
}
