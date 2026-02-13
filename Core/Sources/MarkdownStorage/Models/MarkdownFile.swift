import Foundation

/// Represents a markdown file in the documents container.
public struct MarkdownFile: Identifiable, Hashable, Sendable {
    public var id: URL { url }
    public let url: URL
    public var name: String
    public var relativePath: String
    public var lastModified: Date?
    public var createdDate: Date?
    public var isDirectory: Bool

    // Sync
    public var syncStatus: FileSyncStatus
    public var hasConflict: Bool

    /// Whether the file content is available locally.
    public var isDownloaded: Bool {
        switch syncStatus {
        case .local, .current:
            return true
        case .notDownloaded, .error:
            return false
        }
    }

    // Frontmatter
    public var icon: String?
    public var displayName: String?
    public var tags: [String]

    /// Preferred display title: frontmatter displayName, then filename.
    public var title: String {
        if let displayName, !displayName.isEmpty { return displayName }
        return name
    }

    public init(
        url: URL,
        name: String,
        relativePath: String,
        isDownloaded: Bool = true,
        lastModified: Date? = nil,
        createdDate: Date? = nil,
        isDirectory: Bool = false,
        syncStatus: FileSyncStatus? = nil,
        hasConflict: Bool = false,
        icon: String? = nil,
        displayName: String? = nil,
        tags: [String] = []
    ) {
        self.url = url
        self.name = name
        self.relativePath = relativePath
        self.lastModified = lastModified
        self.createdDate = createdDate
        self.isDirectory = isDirectory
        self.syncStatus = syncStatus ?? (isDownloaded ? .local : .notDownloaded)
        self.hasConflict = hasConflict
        self.icon = icon
        self.displayName = displayName
        self.tags = tags
    }

    // MARK: - Hashable (FileSyncStatus isn't automatically Hashable)

    public func hash(into hasher: inout Hasher) {
        hasher.combine(url)
    }

    public static func == (lhs: MarkdownFile, rhs: MarkdownFile) -> Bool {
        lhs.url == rhs.url
            && lhs.name == rhs.name
            && lhs.relativePath == rhs.relativePath
            && lhs.lastModified == rhs.lastModified
            && lhs.createdDate == rhs.createdDate
            && lhs.isDirectory == rhs.isDirectory
            && lhs.syncStatus == rhs.syncStatus
            && lhs.hasConflict == rhs.hasConflict
            && lhs.icon == rhs.icon
            && lhs.displayName == rhs.displayName
            && lhs.tags == rhs.tags
    }
}
