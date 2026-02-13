import Foundation
import ULID

/// CRUD operations for markdown files in the iCloud Documents container.
public enum MarkdownDocument {
    /// Load the text content of a markdown file.
    public static func loadContent(of file: MarkdownFile) throws -> String {
        try FileCoordinatorIO.readString(at: file.url)
    }

    /// Save text content to a markdown file.
    public static func saveContent(_ content: String, to file: MarkdownFile) throws {
        try FileCoordinatorIO.writeString(content, to: file.url)
    }

    /// Create a new markdown file with a ULID filename in the specified directory.
    /// The `name` is stored as the frontmatter title. Returns the URL of the created file.
    @discardableResult
    public static func createFile(name: String, in directory: URL, content: String = "", icon: String? = nil, tags: [String] = []) throws -> URL {
        let ulid = ULID()
        let url = directory.appendingPathComponent(ulid.ulidString).appendingPathExtension("md")

        // Build frontmatter + body
        let frontmatter = NoteFrontmatter(icon: icon, title: name, tags: tags)
        let fullContent = FrontmatterParser.update(frontmatter, in: content)

        try FileCoordinatorIO.writeString(fullContent, to: url)
        return url
    }

    /// Request download of an iCloud-evicted file.
    public static func startDownloading(_ file: MarkdownFile) throws {
        try FileManager.default.startDownloadingUbiquitousItem(at: file.url)
    }

    /// Delete a markdown file or directory.
    public static func deleteFile(_ file: MarkdownFile) throws {
        try FileCoordinatorIO.delete(at: file.url)
    }

    /// Rename a file to a new name (without extension).
    /// Returns the new URL.
    @discardableResult
    public static func renameFile(_ file: MarkdownFile, to newName: String) throws -> URL {
        let sanitized = sanitizeFilename(newName)
        let newURL: URL
        if file.isDirectory {
            newURL = file.url.deletingLastPathComponent().appendingPathComponent(sanitized)
        } else {
            newURL = file.url.deletingLastPathComponent().appendingPathComponent(sanitized).appendingPathExtension("md")
        }

        guard newURL != file.url else { return file.url }
        try FileCoordinatorIO.move(from: file.url, to: newURL)
        return newURL
    }

    /// Create a folder in the specified directory.
    @discardableResult
    public static func createFolder(name: String, in directory: URL) throws -> URL {
        let sanitized = sanitizeFilename(name)
        let url = directory.appendingPathComponent(sanitized)

        var coordinatorError: NSError?
        var createError: Error?

        let coordinator = NSFileCoordinator()
        coordinator.coordinate(writingItemAt: url, options: .forReplacing, error: &coordinatorError) { coordinatedURL in
            do {
                try FileManager.default.createDirectory(at: coordinatedURL, withIntermediateDirectories: true)
            } catch {
                createError = error
            }
        }

        if let coordinatorError { throw coordinatorError }
        if let createError { throw createError }
        return url
    }

    private static func sanitizeFilename(_ name: String) -> String {
        let illegal = CharacterSet(charactersIn: "/:\\")
        return name.components(separatedBy: illegal).joined(separator: "-").trimmingCharacters(in: .whitespaces)
    }
}
