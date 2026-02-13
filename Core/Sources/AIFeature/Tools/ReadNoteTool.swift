import Conduit
import MarkdownStorage

struct ReadNoteTool: Tool {
    let context: NoteToolContext

    @Generable
    struct Arguments {
        @Guide(description: "The title of the note to read")
        var title: String
    }

    var name: String { "read_note" }
    var description: String { "Read the full content of a note by its title" }

    func call(arguments: Arguments) async throws -> String {
        guard let file = context.findNote(titled: arguments.title) else {
            return #"{"error": "Note not found"}"#
        }
        let content = try MarkdownDocument.loadContent(of: file)
        let escaped = content
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
        return #"{"title": "\#(file.title)", "content": "\#(escaped)"}"#
    }
}
