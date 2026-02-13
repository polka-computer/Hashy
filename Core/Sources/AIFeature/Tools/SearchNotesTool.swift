import Conduit
import Foundation
import MarkdownStorage

struct SearchNotesTool: Tool {
    let context: NoteToolContext

    @Generable
    struct Arguments {
        @Guide(description: "Search query to match against note titles and tags. Use empty string to list all notes.")
        var query: String
    }

    var name: String { "search_notes" }
    var description: String { "Search for notes by title or tag" }

    func call(arguments: Arguments) async throws -> String {
        let query = arguments.query.lowercased()
        let matches: [MarkdownFile]
        if query.isEmpty {
            matches = Array(context.files)
        } else {
            matches = context.files.filter { file in
                file.title.lowercased().contains(query) ||
                file.name.lowercased().contains(query) ||
                file.tags.contains { $0.lowercased().contains(query) }
            }
        }
        let titles = matches.prefix(20).map { "\"\($0.title)\"" }
        return #"{"results": [\#(titles.joined(separator: ", "))], "count": \#(matches.count)}"#
    }
}
