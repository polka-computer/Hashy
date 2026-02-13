import Conduit
import MarkdownStorage

struct ListNotesTool: Tool {
    let context: NoteToolContext

    @Generable
    struct Arguments {}

    var name: String { "list_notes" }
    var description: String { "List all notes with their titles, icons, and tags" }

    func call(arguments: Arguments) async throws -> String {
        let items = context.files.prefix(50).map { file -> String in
            let icon = file.icon ?? ""
            let tags = file.tags.map { "\"\($0)\"" }.joined(separator: ", ")
            return #"{"title": "\#(file.title)", "icon": "\#(icon)", "tags": [\#(tags)]}"#
        }
        return #"{"notes": [\#(items.joined(separator: ", "))], "count": \#(context.files.count)}"#
    }
}
