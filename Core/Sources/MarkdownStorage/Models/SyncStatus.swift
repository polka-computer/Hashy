import Foundation

/// Sync status for an individual file.
public enum FileSyncStatus: Equatable, Sendable {
    case local
    case current
    case notDownloaded
    case error(String)
}

/// Aggregate sync summary across all files.
public struct SyncSummary: Equatable, Sendable {
    public var totalFiles: Int
    public var conflictCount: Int
    public var downloadingCount: Int

    public init(
        totalFiles: Int = 0,
        conflictCount: Int = 0,
        downloadingCount: Int = 0
    ) {
        self.totalFiles = totalFiles
        self.conflictCount = conflictCount
        self.downloadingCount = downloadingCount
    }

    /// Whether everything is fully synced (no conflicts, no pending downloads).
    public var isSynced: Bool {
        conflictCount == 0 && downloadingCount == 0
    }

    /// A short status string for display.
    public var statusText: String {
        if conflictCount > 0 {
            return "\(conflictCount) conflict\(conflictCount == 1 ? "" : "s")"
        }
        if downloadingCount > 0 {
            return "↓ \(downloadingCount)"
        }
        if totalFiles > 0 {
            return "Synced"
        }
        return ""
    }
}
