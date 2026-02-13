import Conduit
import MarkdownStorage

struct UpdateNoteContentTool: Tool {
    let context: NoteToolContext

    @Generable
    struct Arguments {
        @Guide(description: "The title of the note to update")
        var title: String
        @Guide(description: "The new markdown content")
        var content: String
        @Guide(description: "Either replace or append")
        var mode: String
    }

    var name: String { "update_note_content" }
    var description: String { "Replace or append to a note's body content" }

    func call(arguments: Arguments) async throws -> String {
        guard let file = context.findNote(titled: arguments.title) else {
            return #"{"error": "Note not found"}"#
        }
        let existing = try MarkdownDocument.loadContent(of: file)
        let fm = FrontmatterParser.parse(from: existing) ?? NoteFrontmatter()
        let body = FrontmatterParser.body(of: existing)

        let newBody: String
        if arguments.mode.lowercased() == "append" {
            newBody = body + "\n\n" + arguments.content
        } else {
            newBody = arguments.content
        }

        let updated = FrontmatterParser.update(fm, in: newBody)
        try MarkdownDocument.saveContent(updated, to: file)
        return #"{"success": true, "title": "\#(file.title)"}"#
    }
}
