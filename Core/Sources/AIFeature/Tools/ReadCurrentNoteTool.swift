import Conduit
import MarkdownStorage

struct ReadCurrentNoteTool: Tool {
    let context: NoteToolContext

    @Generable
    struct Arguments {}

    var name: String { "read_current_note" }
    var description: String { "Read the currently open note in the editor" }

    func call(arguments: Arguments) async throws -> String {
        guard let url = context.selectedFileURL,
              let file = context.files.first(where: { $0.url == url }) else {
            return #"{"error": "No note is currently open"}"#
        }
        let content = try MarkdownDocument.loadContent(of: file)
        let escaped = content
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
        return #"{"title": "\#(file.title)", "content": "\#(escaped)"}"#
    }
}
