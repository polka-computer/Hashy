import Conduit
import MarkdownStorage

struct CreateNoteTool: Tool {
    let context: NoteToolContext

    @Generable
    struct Arguments {
        @Guide(description: "The title of the note")
        var title: String
        @Guide(description: "A single emoji icon that represents the note")
        var icon: String
        @Guide(description: "1-3 short lowercase tags for categorization (single words or hyphenated-words, no spaces)")
        var tags: [String]
        @Guide(description: "The markdown body content of the note")
        var content: String
    }

    var name: String { "create_note" }
    var description: String { "Create a new note with title, icon, tags, and content" }

    func call(arguments: Arguments) async throws -> String {
        let url = try MarkdownDocument.createFile(
            name: arguments.title,
            in: context.documentsDirectory,
            content: arguments.content,
            icon: arguments.icon,
            tags: arguments.tags
        )
        return #"{"success": true, "title": "\#(arguments.title)", "url": "\#(url.lastPathComponent)"}"#
    }
}
