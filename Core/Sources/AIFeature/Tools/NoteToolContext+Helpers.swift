import MarkdownStorage

extension NoteToolContext {
    /// Finds a note by title (case-insensitive match against title or filename).
    func findNote(titled title: String) -> MarkdownFile? {
        let lower = title.lowercased()
        return files.first {
            $0.title.lowercased() == lower || $0.name.lowercased() == lower
        }
    }
}
