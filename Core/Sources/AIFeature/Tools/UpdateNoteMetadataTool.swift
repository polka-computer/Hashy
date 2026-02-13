import Conduit
import MarkdownStorage

struct UpdateNoteMetadataTool: Tool {
    let context: NoteToolContext

    @Generable
    struct Arguments {
        @Guide(description: "The title of the note to update")
        var title: String
        @Guide(description: "New emoji icon for the note")
        var icon: String
        @Guide(description: "New tags for the note (single words or hyphenated-words, no spaces)")
        var tags: [String]
    }

    var name: String { "update_note_metadata" }
    var description: String { "Update an existing note's icon and/or tags" }

    func call(arguments: Arguments) async throws -> String {
        guard let file = context.findNote(titled: arguments.title) else {
            return #"{"error": "Note not found"}"#
        }
        let content = try MarkdownDocument.loadContent(of: file)
        var fm = FrontmatterParser.parse(from: content) ?? NoteFrontmatter()
        if !arguments.icon.isEmpty { fm.icon = arguments.icon }
        if !arguments.tags.isEmpty { fm.tags = arguments.tags }
        let body = FrontmatterParser.body(of: content)
        let updated = FrontmatterParser.update(fm, in: body)
        try MarkdownDocument.saveContent(updated, to: file)
        return #"{"success": true, "title": "\#(file.title)"}"#
    }
}
