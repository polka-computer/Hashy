import Conduit
import MarkdownStorage

struct DeleteNoteTool: Tool {
    let context: NoteToolContext

    @Generable
    struct Arguments {
        @Guide(description: "The title of the note to delete")
        var title: String
    }

    var name: String { "delete_note" }
    var description: String { "Delete a note by its title" }

    func call(arguments: Arguments) async throws -> String {
        guard let file = context.findNote(titled: arguments.title) else {
            return #"{"error": "Note not found"}"#
        }
        try MarkdownDocument.deleteFile(file)
        return #"{"success": true, "title": "\#(file.title)"}"#
    }
}
