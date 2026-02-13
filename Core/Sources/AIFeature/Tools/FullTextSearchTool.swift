import Conduit
import MarkdownStorage

struct FullTextSearchTool: Tool {
    let context: NoteToolContext

    @Generable
    struct Arguments {
        @Guide(description: "Text to search for inside note content")
        var query: String
    }

    var name: String { "full_text_search" }
    var description: String { "Search inside note body text for matching content" }

    func call(arguments: Arguments) async throws -> String {
        let query = arguments.query.lowercased()
        guard !query.isEmpty else {
            return #"{"error": "Query cannot be empty"}"#
        }

        var results: [(title: String, snippet: String)] = []
        for file in context.files {
            guard let content = try? MarkdownDocument.loadContent(of: file) else { continue }
            let body = FrontmatterParser.body(of: content)
            if body.lowercased().contains(query) {
                let lower = body.lowercased()
                if let range = lower.range(of: query) {
                    let start = body.index(range.lowerBound, offsetBy: -50, limitedBy: body.startIndex) ?? body.startIndex
                    let end = body.index(range.upperBound, offsetBy: 50, limitedBy: body.endIndex) ?? body.endIndex
                    let snippet = String(body[start..<end])
                        .replacingOccurrences(of: "\n", with: " ")
                        .replacingOccurrences(of: "\"", with: "'")
                    results.append((file.title, snippet))
                }
            }
            if results.count >= 20 { break }
        }

        let items = results.map { #"{"title": "\#($0.title)", "snippet": "\#($0.snippet)"}"# }
        return #"{"results": [\#(items.joined(separator: ", "))], "count": \#(results.count)}"#
    }
}
