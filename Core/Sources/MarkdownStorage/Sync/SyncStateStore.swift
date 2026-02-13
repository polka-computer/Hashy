import CryptoKit
import Foundation
import OSLog

/// Local-only per-device file hash tracking for conflict detection.
/// Stores state in the app sandbox (NOT in the synced folder).
public final class SyncStateStore: @unchecked Sendable {
    private var state: SyncState
    private let fileURL: URL
    private let lock = NSLock()
    private let logger = Logger(subsystem: "ca.long.tail.labs.hashy", category: "SyncStateStore")

    public init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = appSupport.appendingPathComponent("ca.long.tail.labs.hashy")
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        self.fileURL = dir.appendingPathComponent("sync-state.json")

        if let data = try? Data(contentsOf: fileURL),
           let loaded = try? JSONDecoder().decode(SyncState.self, from: data) {
            self.state = loaded
        } else {
            self.state = SyncState()
        }
    }

    /// Record the current state of a file after load or save.
    public func record(relativePath: String, content: String, modDate: Date) {
        lock.lock()
        defer { lock.unlock() }
        let hash = Self.sha256(content)
        state.files[relativePath] = FileSnapshot(
            contentHash: hash,
            modDate: modDate,
            size: content.utf8.count
        )
        persist()
    }

    /// Check if a file has been changed externally since we last recorded it.
    /// Returns true if the file differs from our last known state (= another device changed it).
    public func hasExternalChange(relativePath: String, currentContent: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard let snapshot = state.files[relativePath] else {
            // Never seen this file — not an external change from our perspective
            return false
        }
        let currentHash = Self.sha256(currentContent)
        return currentHash != snapshot.contentHash
    }

    /// Get the last recorded hash for a file.
    public func lastKnownHash(relativePath: String) -> String? {
        lock.lock()
        defer { lock.unlock() }
        return state.files[relativePath]?.contentHash
    }

    /// Remove tracking for a deleted file.
    public func remove(relativePath: String) {
        lock.lock()
        defer { lock.unlock() }
        state.files.removeValue(forKey: relativePath)
        persist()
    }

    /// Compute SHA256 hex digest a string.
    public static func sha256(_ string: String) -> String {
        let data = Data(string.utf8)
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private func persist() {
        do {
            let data = try JSONEncoder().encode(state)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            logger.error("Failed to persist sync state: \(error.localizedDescription, privacy: .public)")
        }
    }
}

private struct SyncState: Codable {
    var files: [String: FileSnapshot] = [:]
}

private struct FileSnapshot: Codable {
    var contentHash: String
    var modDate: Date
    var size: Int
}
