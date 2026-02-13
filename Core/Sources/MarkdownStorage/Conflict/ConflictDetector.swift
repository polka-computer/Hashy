import Foundation

/// Detects and resolves sync conflicts using hash-based detection via SyncStateStore.
/// Compares the user's unsaved content against the on-disk file state to detect
/// external changes from other devices syncing through iCloud Drive.
public enum ConflictDetector {
    /// Check for a conflict between unsaved editor content and the on-disk file.
    /// Returns a `FileConflict` if the on-disk content differs from what we last recorded
    /// (meaning another device wrote to it), or nil if clean.
    public static func detect(
        at url: URL,
        unsavedContent: String,
        syncStore: SyncStateStore,
        relativePath: String
    ) -> FileConflict? {
        // Read current on-disk content
        guard let diskContent = try? String(contentsOf: url, encoding: .utf8) else {
            return nil
        }

        // Check if on-disk content differs from our last recorded state
        guard syncStore.hasExternalChange(relativePath: relativePath, currentContent: diskContent) else {
            return nil
        }

        // The file changed externally — build a conflict
        let diskModDate = (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date()

        let conflictVersion = ConflictVersion(
            content: diskContent,
            modificationDate: diskModDate,
            originDeviceName: nil
        )

        return FileConflict(
            fileURL: url,
            currentContent: unsavedContent,
            currentModDate: Date(),
            conflictVersions: [conflictVersion]
        )
    }

    /// Resolve a conflict by keeping the chosen version.
    /// - `.keepCurrent` — write the user's unsaved content to disk
    /// - `.keepOther(id)` — keep the on-disk version (no write needed)
    /// - `.keepBoth` — keep user's content in the file, save conflict version as a new file with suffix
    public static func resolve(
        _ conflict: FileConflict,
        keeping resolution: ConflictResolution,
        syncStore: SyncStateStore,
        relativePath: String
    ) {
        let url = conflict.fileURL

        switch resolution {
        case .keepCurrent:
            // Write user's content to disk
            try? conflict.currentContent.write(to: url, atomically: true, encoding: .utf8)
            let modDate = (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date()
            syncStore.record(relativePath: relativePath, content: conflict.currentContent, modDate: modDate)

        case .keepOther(let versionID):
            if let version = conflict.conflictVersions.first(where: { $0.id == versionID }) {
                try? version.content.write(to: url, atomically: true, encoding: .utf8)
                let modDate = (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date()
                syncStore.record(relativePath: relativePath, content: version.content, modDate: modDate)
            }

        case .keepBoth:
            // Keep current content in the original file
            try? conflict.currentContent.write(to: url, atomically: true, encoding: .utf8)
            let modDate = (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date()
            syncStore.record(relativePath: relativePath, content: conflict.currentContent, modDate: modDate)

            // Save the conflict version as a new file with "-conflict-<date>" suffix
            if let version = conflict.conflictVersions.first {
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd-HHmmss"
                let suffix = "-conflict-\(dateFormatter.string(from: version.modificationDate))"

                let originalName = url.deletingPathExtension().lastPathComponent
                let ext = url.pathExtension
                let conflictURL = url.deletingLastPathComponent()
                    .appendingPathComponent(originalName + suffix)
                    .appendingPathExtension(ext)

                try? version.content.write(to: conflictURL, atomically: true, encoding: .utf8)
            }
        }
    }
}
