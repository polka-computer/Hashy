import Foundation

/// Represents an iCloud sync conflict with version metadata.
public struct FileConflict: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let fileURL: URL
    public let currentContent: String
    public let currentModDate: Date
    public let conflictVersions: [ConflictVersion]

    public init(
        id: UUID = UUID(),
        fileURL: URL,
        currentContent: String,
        currentModDate: Date,
        conflictVersions: [ConflictVersion]
    ) {
        self.id = id
        self.fileURL = fileURL
        self.currentContent = currentContent
        self.currentModDate = currentModDate
        self.conflictVersions = conflictVersions
    }
}

/// How to resolve a file conflict.
public enum ConflictResolution: Equatable, Sendable {
    case keepCurrent
    case keepOther(UUID)
    case keepBoth
}

/// A single conflict version from another device.
public struct ConflictVersion: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let content: String
    public let modificationDate: Date
    public let originDeviceName: String?

    public init(
        id: UUID = UUID(),
        content: String,
        modificationDate: Date,
        originDeviceName: String? = nil
    ) {
        self.id = id
        self.content = content
        self.modificationDate = modificationDate
        self.originDeviceName = originDeviceName
    }
}
