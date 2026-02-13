import Foundation

enum SystemPromptBuilder {
    static func build(
        noteCount: Int,
        existingTags: [String],
        currentNoteContext: String?
    ) -> String {
        var text = """
        You are a helpful AI assistant integrated into a markdown note-taking app called Hashy. \
        You can create, read, search, update, and delete notes using the provided tools. \
        When the user asks you to create a note, immediately use the create_note tool — do NOT ask for confirmation. \
        When the user asks you to update multiple notes (e.g. add emojis to all notes), \
        use search_notes to list them, then call update_note_metadata for EACH note — do not stop after one. \
        Infer a good title, pick a fitting emoji icon, choose relevant tags (use single words or hyphenated-words, never spaces in tags), and generate useful content. \
        Be concise and act on requests directly.
        """

        text += "\n\nThe user has \(noteCount) notes."

        if !existingTags.isEmpty {
            text += "\n\nExisting tags in the project: \(existingTags.joined(separator: ", ")). Prefer reusing these when relevant."
        }

        if let context = currentNoteContext, !context.isEmpty {
            let truncated = String(context.prefix(4000))
            text += "\n\nThe user is currently viewing this note:\n\n\(truncated)"
        }

        return text
    }
}
