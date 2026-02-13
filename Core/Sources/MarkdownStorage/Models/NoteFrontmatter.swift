import Foundation
import Frontmatter

/// Frontmatter metadata for a note file.
public struct NoteFrontmatter: Codable, Equatable, Sendable {
    public var icon: String?
    public var title: String?
    public var tags: [String]

    public init(icon: String? = nil, title: String? = nil, tags: [String] = []) {
        self.icon = icon
        self.title = title
        self.tags = tags
    }

    /// Whether this frontmatter has any meaningful content.
    public var isEmpty: Bool {
        (icon == nil || icon?.isEmpty == true) &&
        (title == nil || title?.isEmpty == true) &&
        tags.isEmpty
    }

    enum CodingKeys: String, CodingKey {
        case icon, title, tags
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        icon = try container.decodeIfPresent(String.self, forKey: .icon)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        tags = (try? container.decodeIfPresent([String].self, forKey: .tags)) ?? []
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        // Only encode non-nil, non-empty values
        if let icon, !icon.isEmpty {
            try container.encode(icon, forKey: .icon)
        }
        if let title, !title.isEmpty {
            try container.encode(title, forKey: .title)
        }
        if !tags.isEmpty {
            try container.encode(tags, forKey: .tags)
        }
    }
}

/// Parses and updates YAML frontmatter in markdown content using the Frontmatter library.
public enum FrontmatterParser {
    /// Parse frontmatter from markdown content string.
    public static func parse(from content: String) -> NoteFrontmatter? {
        try? Frontmatter.decode(NoteFrontmatter.self, contents: content)
    }

    /// Parse frontmatter from a file URL (reads first ~1KB for efficiency).
    public static func parse(from url: URL) -> NoteFrontmatter? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }

        guard let data = try? handle.read(upToCount: 1024),
              let header = String(data: data, encoding: .utf8) else { return nil }

        return parse(from: header)
    }

    /// Update frontmatter in content, inserting or replacing as needed.
    /// If frontmatter is empty, returns plain body without frontmatter block.
    public static func update(_ frontmatter: NoteFrontmatter, in content: String) -> String {
        let body = stripFrontmatter(from: content)
        // Don't write empty frontmatter blocks
        if frontmatter.isEmpty {
            return body
        }
        if let encoded = try? Frontmatter.encode(frontmatter, contents: body) {
            return encoded
        }
        return body
    }

    /// Strip frontmatter from content, returning just the body.
    public static func body(of content: String) -> String {
        stripFrontmatter(from: content)
    }

    // MARK: - Private

    private static func stripFrontmatter(from content: String) -> String {
        guard content.hasPrefix("---") else { return content }

        let lines = content.components(separatedBy: "\n")
        guard lines.count >= 2 else { return content }

        for i in 1..<lines.count {
            if lines[i].trimmingCharacters(in: .whitespaces) == "---" {
                let bodyLines = Array(lines[(i + 1)...])
                let body = bodyLines.joined(separator: "\n")
                if body.hasPrefix("\n") {
                    return String(body.dropFirst())
                }
                return body
            }
        }

        return content
    }
}
