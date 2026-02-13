import Conduit
import MarkdownStorage

struct RenameNoteTool: Tool {
    let context: NoteToolContext

    @Generable
    struct Arguments {
        @Guide(description: "The current title of the note")
        var title: String
        @Guide(description: "The new title for the note")
        var newTitle: String
    }

    var name: String { "rename_note" }
    var description: String { "Change a note's title" }

    func call(arguments: Arguments) async throws -> String {
        guard let file = context.findNote(titled: arguments.title) else {
            return #"{"error": "Note not found"}"#
        }
        let content = try MarkdownDocument.loadContent(of: file)
        var fm = FrontmatterParser.parse(from: content) ?? NoteFrontmatter()
        fm.title = arguments.newTitle
        let body = FrontmatterParser.body(of: content)
        let updated = FrontmatterParser.update(fm, in: body)
        try MarkdownDocument.saveContent(updated, to: file)
        return #"{"success": true, "oldTitle": "\#(arguments.title)", "newTitle": "\#(arguments.newTitle)"}"#
    }
}
