import Conduit
import MarkdownStorage

struct ListTagsTool: Tool {
    let context: NoteToolContext

    @Generable
    struct Arguments {}

    var name: String { "list_tags" }
    var description: String { "List all unique tags across all notes" }

    func call(arguments: Arguments) async throws -> String {
        let allTags = Set(context.files.flatMap(\.tags)).sorted()
        let quoted = allTags.map { "\"\($0)\"" }
        return #"{"tags": [\#(quoted.joined(separator: ", "))], "count": \#(allTags.count)}"#
    }
}
