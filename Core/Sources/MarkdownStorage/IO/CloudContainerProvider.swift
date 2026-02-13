import Foundation
import OSLog

/// Locates and provides access to the documents container.
/// Supports a user-chosen custom folder (via security-scoped bookmark),
/// iCloud Drive folder, or local fallback.
public enum CloudContainerProvider {
    private static let logger = Logger(subsystem: "ca.long.tail.labs.hashy", category: "CloudContainer")

    /// UserDefaults key for the security-scoped bookmark.
    private static let bookmarkKey = "customVaultBookmark"

    /// Tracks whether we've started accessing the security-scoped resource this session.
    nonisolated(unsafe) private static var accessingSecurityScope = false
    nonisolated(unsafe) private static var resolvedCustomURL: URL?
    nonisolated(unsafe) private static var resolvedDriveURL: URL?
    nonisolated(unsafe) private static var resolvedFallbackURL: URL?

    /// Whether iCloud is signed in on this device.
    public static var isICloudSignedIn: Bool {
        FileManager.default.ubiquityIdentityToken != nil
    }

    /// Returns the Documents directory URL based on priority:
    /// 1. Custom folder (if user has chosen one via security-scoped bookmark)
    /// 2. iCloud Drive folder (macOS only — ~/Library/Mobile Documents/com~apple~CloudDocs/Hashy/)
    /// 3. Local fallback
    /// Call on a background thread — this can block on first access.
    public static func documentsDirectory() -> URL {
        let url: URL

        // 1. Custom folder from security-scoped bookmark
        if let custom = resolveCustomDirectory() {
            url = custom
        }
        // 2. iCloud Drive folder
        else if let driveURL = resolveICloudDriveDirectory() {
            url = driveURL
        }
        // 3. Fallback: local Documents directory
        else {
            if let cached = resolvedFallbackURL {
                url = cached
            } else {
                let fallback = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                    .appendingPathComponent("Hashy")
                if !FileManager.default.fileExists(atPath: fallback.path) {
                    try? FileManager.default.createDirectory(at: fallback, withIntermediateDirectories: true)
                }
                resolvedFallbackURL = fallback
                logger.info("Using local fallback directory: \(fallback.path, privacy: .public)")
                url = fallback
            }
        }

        // Install Claude Code skill into the vault
        VaultSkillInstaller.installIfNeeded(in: url)

        return url
    }

    /// Whether iCloud Drive is available for storing files.
    /// On iOS, also returns true when the user's custom folder is inside iCloud Drive.
    public static var isCloudAvailable: Bool {
        if resolveICloudDriveDirectory() != nil { return true }
        // On iOS the user picks the iCloud Drive folder via document picker,
        // stored as a custom directory bookmark. Detect that case.
        if let custom = resolveCustomDirectory() {
            return custom.path.contains("com~apple~CloudDocs")
        }
        return false
    }

    /// Whether a custom directory is currently configured.
    public static var isUsingCustomDirectory: Bool {
        UserDefaults.standard.data(forKey: bookmarkKey) != nil
    }

    /// A display-friendly description of the current vault path.
    public static var currentDirectoryDescription: String {
        if let url = resolveCustomDirectory() {
            return url.path.replacingOccurrences(of: NSHomeDirectory(), with: "~")
        }
        if isCloudAvailable {
            return "iCloud Drive"
        }
        return "Local Storage"
    }

    /// Save a user-chosen folder as a security-scoped bookmark.
    /// Call after the user picks a folder via NSOpenPanel or UIDocumentPickerViewController.
    public static func setCustomDirectory(url: URL) throws {
        #if os(macOS)
        let bookmarkData = try url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        #else
        let bookmarkData = try url.bookmarkData(
            options: [],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        #endif
        UserDefaults.standard.set(bookmarkData, forKey: bookmarkKey)
        // Reset cached state so next call to documentsDirectory() picks up the new folder
        stopAccessingCustomDirectory()
        resolvedCustomURL = nil
        logger.info("Saved custom vault directory bookmark: \(url.path, privacy: .public)")
    }

    /// Remove the custom folder bookmark, reverting to iCloud/local default.
    public static func clearCustomDirectory() {
        stopAccessingCustomDirectory()
        resolvedCustomURL = nil
        UserDefaults.standard.removeObject(forKey: bookmarkKey)
        logger.info("Cleared custom vault directory bookmark")
    }

    // MARK: - Private

    /// Resolve the stored security-scoped bookmark to a URL.
    /// Starts accessing the security-scoped resource if needed.
    private static func resolveCustomDirectory() -> URL? {
        // Return cached URL if already resolved this session
        if let cached = resolvedCustomURL, accessingSecurityScope {
            return cached
        }

        guard let bookmarkData = UserDefaults.standard.data(forKey: bookmarkKey) else {
            return nil
        }

        var isStale = false
        #if os(macOS)
        guard let url = try? URL(
            resolvingBookmarkData: bookmarkData,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else {
            // Bookmark is broken — clear it
            logger.error("Failed to resolve custom vault bookmark, clearing bookmark")
            clearCustomDirectory()
            return nil
        }
        #else
        guard let url = try? URL(
            resolvingBookmarkData: bookmarkData,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else {
            logger.error("Failed to resolve custom vault bookmark, clearing bookmark")
            clearCustomDirectory()
            return nil
        }
        #endif

        // Re-save if stale
        if isStale {
            try? setCustomDirectory(url: url)
            logger.info("Custom vault bookmark was stale and has been refreshed")
        }

        // Start accessing security-scoped resource
        if !accessingSecurityScope {
            let started = url.startAccessingSecurityScopedResource()
            logger.info("Started accessing security-scoped vault resource: \(started, privacy: .public)")
            accessingSecurityScope = true
        }

        resolvedCustomURL = url
        return url
    }

    private static func stopAccessingCustomDirectory() {
        if accessingSecurityScope, let url = resolvedCustomURL {
            url.stopAccessingSecurityScopedResource()
            accessingSecurityScope = false
            logger.info("Stopped accessing security-scoped vault resource: \(url.path, privacy: .public)")
        }
    }

    /// Resolve the iCloud Drive folder for this app.
    /// macOS: Auto-creates ~/Library/Mobile Documents/com~apple~CloudDocs/Hashy/ when iCloud is signed in.
    /// iOS: Returns nil — iOS must use the folder picker (security-scoped bookmark) instead.
    private static func resolveICloudDriveDirectory() -> URL? {
        if let cached = resolvedDriveURL {
            return cached
        }

        #if os(macOS)
        // Check iCloud is signed in
        guard FileManager.default.ubiquityIdentityToken != nil else {
            logger.info("iCloud not signed in, skipping iCloud Drive directory")
            return nil
        }

        let mobileDocs = (NSHomeDirectory() as NSString).appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs/Hashy")
        let driveURL = URL(fileURLWithPath: mobileDocs, isDirectory: true)

        if !FileManager.default.fileExists(atPath: driveURL.path) {
            do {
                try FileManager.default.createDirectory(at: driveURL, withIntermediateDirectories: true)
                logger.info("Created iCloud Drive directory: \(driveURL.path, privacy: .public)")
            } catch {
                logger.error("Failed to create iCloud Drive directory: \(error.localizedDescription, privacy: .public)")
                return nil
            }
        }

        resolvedDriveURL = driveURL
        return driveURL
        #else
        // iOS cannot directly access iCloud Drive — user must pick via document picker
        return nil
        #endif
    }
}
