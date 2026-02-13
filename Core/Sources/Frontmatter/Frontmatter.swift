import Foundation
import Yams

public enum Frontmatter {
    public enum Error: Swift.Error {
        case invalidFormat(String)
        case invalidData
        case decoding(Swift.Error)
        case encoding(Swift.Error)
    }

    private static let separator = "---\n"

    // MARK: - Decode

    public static func decode<T: Decodable>(
        _ type: T.Type = T.self,
        contents: String
    ) throws(Error) -> T {
        // Native split omits empty subsequences, so parts[0] == YAML content
        let parts = contents.split(separator: "---\n")
        guard contents.hasFrontmatter, parts.count >= 2 else {
            throw .invalidFormat(contents)
        }
        let yaml = String(parts[0])
        do {
            return try YAMLDecoder().decode(T.self, from: yaml)
        } catch {
            throw .decoding(error)
        }
    }

    // MARK: - Encode

    @discardableResult
    public static func encode<T: Encodable>(
        _ value: T,
        contents: String = ""
    ) throws(Error) -> String {
        let yaml: String
        do {
            yaml = try YAMLEncoder().encode(value)
        } catch {
            throw .encoding(error)
        }
        return contents.withFrontmatter(yaml, separator: separator)
    }
}

// MARK: - String helpers

private extension String {
    /// Uses Swift's native `split(separator:)` (available iOS 16+)
    /// which omits empty subsequences — so parts[0] is the YAML block.
    var hasFrontmatter: Bool {
        let parts = self.split(separator: "---\n")
        return parts.count >= 2
            && trimmingCharacters(in: .newlines).hasPrefix("---\n")
    }

    func withFrontmatter(_ yaml: String, separator: String) -> String {
        let yamlBlock = separator + yaml.addingLinebreakSuffix + separator
        if hasFrontmatter {
            // Use components(separatedBy:) here so we can reconstruct with the body after the first separator pair
            let parts = components(separatedBy: separator)
            // parts: ["", yamlContent, body...]
            let body = parts.dropFirst(2).joined(separator: separator)
            return yamlBlock + body
        } else {
            return yamlBlock + "\n" + self
        }
    }

    var addingLinebreakSuffix: String {
        hasSuffix("\n") ? self : self + "\n"
    }
}
