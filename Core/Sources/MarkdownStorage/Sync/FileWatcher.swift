import Foundation
import Combine
import OSLog

/// Watches the documents container for .md/.txt file changes.
/// Uses a local DispatchSource file system watcher.
/// Outputs a flat list of files (no directories), sorted by most recently modified.
@MainActor
public final class FileWatcher: ObservableObject {
    @Published public private(set) var files: [MarkdownFile] = []
    private let logger = Logger(subsystem: "ca.long.tail.labs.hashy", category: "FileWatcher")

    /// Computed sync summary from the current file list.
    public var syncSummary: SyncSummary {
        var summary = SyncSummary()
        summary.totalFiles = files.count
        for file in files {
            if file.hasConflict {
                summary.conflictCount += 1
            }
            if file.syncStatus == .notDownloaded {
                summary.downloadingCount += 1
            }
        }
        return summary
    }

    nonisolated(unsafe) private var localSource: DispatchSourceFileSystemObject?
    nonisolated(unsafe) private var localFileDescriptor: Int32 = -1
    nonisolated(unsafe) private var metadataQuery: NSMetadataQuery?
    nonisolated(unsafe) private var queryObservers: [NSObjectProtocol] = []
    nonisolated(unsafe) private var metadataDebounceWork: DispatchWorkItem?
    nonisolated(unsafe) private var evictedRescanWork: DispatchWorkItem?
    nonisolated(unsafe) private var evictedRescanAttempts: Int = 0
    private let documentsURL: URL
    private let normalizedDocumentsPath: String
    private let alternateDocumentsPath: String
    private let normalizedDocumentsPathLowercased: String
    private let alternateDocumentsPathLowercased: String

    public init(documentsURL: URL) {
        self.documentsURL = documentsURL
        self.normalizedDocumentsPath = documentsURL.resolvingSymlinksInPath().standardizedFileURL.path
        if normalizedDocumentsPath.hasPrefix("/private/") {
            self.alternateDocumentsPath = String(normalizedDocumentsPath.dropFirst("/private".count))
        } else {
            self.alternateDocumentsPath = "/private" + normalizedDocumentsPath
        }
        self.normalizedDocumentsPathLowercased = self.normalizedDocumentsPath.lowercased()
        self.alternateDocumentsPathLowercased = self.alternateDocumentsPath.lowercased()
    }

    deinit {
        localSource?.cancel()
        localSource = nil
        if localFileDescriptor >= 0 {
            close(localFileDescriptor)
            localFileDescriptor = -1
        }
        evictedRescanWork?.cancel()
        metadataDebounceWork?.cancel()
        metadataQuery?.stop()
        for observer in queryObservers {
            NotificationCenter.default.removeObserver(observer)
        }
        queryObservers.removeAll()
        metadataQuery = nil
    }

    public func start() {
        logger.info(
            "Starting file watcher path=\(self.documentsURL.path, privacy: .public)"
        )
        scanLocalFiles()
        startLocalWatcher()
        startMetadataQuery()
    }

    public func stop() {
        logger.info("Stopping file watcher")
        localSource?.cancel()
        localSource = nil
        if localFileDescriptor >= 0 {
            close(localFileDescriptor)
            localFileDescriptor = -1
        }
        stopMetadataQuery()
    }

    // MARK: - Local File Watching

    private func startLocalWatcher() {
        let fd = open(documentsURL.path, O_EVTONLY)
        guard fd >= 0 else {
            logger.error("Failed to open local directory watcher fd for path \(self.documentsURL.path, privacy: .public)")
            return
        }
        localFileDescriptor = fd

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .delete, .rename, .extend],
            queue: .main
        )

        source.setEventHandler { [weak self] in
            self?.logger.debug("Local filesystem event received, rescanning notes")
            self?.scanLocalFiles()
        }

        source.setCancelHandler {
            close(fd)
        }

        localSource = source
        source.resume()
        logger.info("Local filesystem watcher active")
    }

    private func scanLocalFiles() {
        var result: [MarkdownFile] = []
        scanRecursively(directory: documentsURL, relativeTo: documentsURL, into: &result)
        files = result.sorted { ($0.lastModified ?? .distantPast) > ($1.lastModified ?? .distantPast) }
        let evictedCount = files.filter { $0.syncStatus == .notDownloaded }.count
        let localCount = files.count - evictedCount
        logger.debug("Local scan complete: total=\(self.files.count, privacy: .public) local=\(localCount, privacy: .public) evicted=\(evictedCount, privacy: .public)")

        // Schedule periodic rescan while evicted files remain so UI updates after downloads complete
        evictedRescanWork?.cancel()
        if evictedCount > 0 && evictedRescanAttempts < 15 {
            evictedRescanAttempts += 1
            let work = DispatchWorkItem { [weak self] in
                self?.logger.debug("Evicted rescan attempt \(self?.evictedRescanAttempts ?? 0, privacy: .public)")
                self?.scanLocalFiles()
            }
            evictedRescanWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0, execute: work)
        } else if evictedCount == 0 {
            evictedRescanAttempts = 0
        }
    }

    private func scanRecursively(directory: URL, relativeTo root: URL, into result: inout [MarkdownFile]) {
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey, .creationDateKey, .ubiquitousItemDownloadingStatusKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        for url in contents {
            let resourceValues = try? url.resourceValues(forKeys: [.isDirectoryKey, .contentModificationDateKey, .creationDateKey, .ubiquitousItemDownloadingStatusKey])
            let isDir = resourceValues?.isDirectory ?? false
            let relativePath = url.path.replacingOccurrences(of: root.path + "/", with: "")

            if isDir {
                scanRecursively(directory: url, relativeTo: root, into: &result)
            } else if url.pathExtension == "md" || url.pathExtension == "txt" {
                let isEvicted: Bool
                if let downloadStatus = resourceValues?.ubiquitousItemDownloadingStatus,
                   downloadStatus == .notDownloaded {
                    isEvicted = true
                } else {
                    isEvicted = false
                }

                let lastModified = resourceValues?.contentModificationDate
                let createdDate = resourceValues?.creationDate

                var icon: String?
                var displayName: String?
                var tags: [String] = []

                // Only parse frontmatter for locally available files
                if !isEvicted, let fm = FrontmatterParser.parse(from: url) {
                    icon = fm.icon
                    displayName = fm.title
                    tags = fm.tags
                }

                let syncStatus: FileSyncStatus = isEvicted ? .notDownloaded : .local

                result.append(MarkdownFile(
                    url: url,
                    name: url.deletingPathExtension().lastPathComponent,
                    relativePath: relativePath,
                    lastModified: lastModified,
                    createdDate: createdDate,
                    isDirectory: false,
                    syncStatus: syncStatus,
                    hasConflict: false,
                    icon: icon,
                    displayName: displayName,
                    tags: tags
                ))

                // Trigger download for evicted iCloud files
                if isEvicted {
                    logger.debug("Requesting download for evicted file: \(url.lastPathComponent, privacy: .public)")
                    do {
                        try FileManager.default.startDownloadingUbiquitousItem(at: url)
                    } catch {
                        logger.error("Failed to start download for \(url.lastPathComponent, privacy: .public): \(error.localizedDescription, privacy: .public)")
                    }
                }
            }
        }
    }

    // MARK: - iCloud Metadata Query

    private func startMetadataQuery() {
        let query = NSMetadataQuery()
        let fileFilter = NSPredicate(
            format: "%K LIKE '*.md' OR %K LIKE '*.txt'",
            NSMetadataItemFSNameKey, NSMetadataItemFSNameKey
        )
        let pathFilter = NSPredicate(
            format: "%K BEGINSWITH %@",
            NSMetadataItemPathKey, documentsURL.path
        )
        query.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [fileFilter, pathFilter])
        // Use both scopes: app's own ubiquity container + externally accessible iCloud Drive
        query.searchScopes = [
            NSMetadataQueryUbiquitousDocumentsScope,
            NSMetadataQueryAccessibleUbiquitousExternalDocumentsScope
        ]
        query.notificationBatchingInterval = 0.25
        logger.info("Metadata query scope path=\(self.documentsURL.path, privacy: .public)")

        let gatherObserver = NotificationCenter.default.addObserver(
            forName: .NSMetadataQueryDidFinishGathering,
            object: query,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.logger.info("Metadata query initial gather complete — items=\(query.resultCount)")
                self.logMetadataQueryItems(query)
                self.handleMetadataQueryUpdate()
            }
        }

        let updateObserver = NotificationCenter.default.addObserver(
            forName: .NSMetadataQueryDidUpdate,
            object: query,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.logger.debug("Metadata query update received — items=\(query.resultCount)")
                self.logMetadataQueryItems(query)
                self.handleMetadataQueryUpdate()
            }
        }

        queryObservers = [gatherObserver, updateObserver]
        metadataQuery = query
        query.start()
        logger.info("iCloud metadata query started")
    }

    private func logMetadataQueryItems(_ query: NSMetadataQuery) {
        query.disableUpdates()
        defer { query.enableUpdates() }

        var downloaded = 0
        var downloading = 0
        var notDownloaded = 0
        var unknown = 0

        for i in 0..<query.resultCount {
            guard let item = query.result(at: i) as? NSMetadataItem,
                  let name = item.value(forAttribute: NSMetadataItemFSNameKey) as? String else { continue }
            let status = item.value(forAttribute: NSMetadataUbiquitousItemDownloadingStatusKey) as? String
            let percent = item.value(forAttribute: NSMetadataUbiquitousItemPercentDownloadedKey) as? Double

            switch status {
            case NSMetadataUbiquitousItemDownloadingStatusCurrent:
                downloaded += 1
            case NSMetadataUbiquitousItemDownloadingStatusDownloaded:
                downloaded += 1
            case NSMetadataUbiquitousItemDownloadingStatusNotDownloaded:
                notDownloaded += 1
                let pct = percent.map { String(format: "%.0f%%", $0) } ?? "n/a"
                logger.debug("  not downloaded: \(name, privacy: .public) progress=\(pct, privacy: .public)")
            default:
                if let percent {
                    downloading += 1
                    logger.debug("  downloading: \(name, privacy: .public) progress=\(String(format: "%.0f%%", percent), privacy: .public)")
                } else {
                    unknown += 1
                    logger.debug("  unknown status: \(name, privacy: .public) raw=\(status ?? "nil", privacy: .public)")
                }
            }
        }
        logger.info("Metadata summary: downloaded=\(downloaded) downloading=\(downloading) notDownloaded=\(notDownloaded) unknown=\(unknown)")
    }

    private func handleMetadataQueryUpdate() {
        metadataDebounceWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.logger.debug("Metadata debounce fired, rescanning files")
            self?.scanLocalFiles()
        }
        metadataDebounceWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: work)
    }

    private func stopMetadataQuery() {
        metadataDebounceWork?.cancel()
        metadataDebounceWork = nil
        metadataQuery?.stop()
        for observer in queryObservers {
            NotificationCenter.default.removeObserver(observer)
        }
        queryObservers.removeAll()
        metadataQuery = nil
        logger.info("iCloud metadata query stopped")
    }

    func relativePathFromDocuments(_ url: URL) -> String {
        let normalizedFilePath = url.resolvingSymlinksInPath().standardizedFileURL.path
        let normalizedLower = normalizedFilePath.lowercased()

        if normalizedLower.hasPrefix(normalizedDocumentsPathLowercased + "/") {
            return String(normalizedFilePath.dropFirst(normalizedDocumentsPath.count + 1))
        }
        if normalizedLower.hasPrefix(alternateDocumentsPathLowercased + "/") {
            return String(normalizedFilePath.dropFirst(alternateDocumentsPath.count + 1))
        }
        return url.lastPathComponent
    }

    func isInDocumentsScope(_ url: URL) -> Bool {
        let normalizedFilePath = url.resolvingSymlinksInPath().standardizedFileURL.path
        let normalizedLower = normalizedFilePath.lowercased()

        if normalizedLower == normalizedDocumentsPathLowercased || normalizedLower.hasPrefix(normalizedDocumentsPathLowercased + "/") {
            return true
        }
        if normalizedLower == alternateDocumentsPathLowercased || normalizedLower.hasPrefix(alternateDocumentsPathLowercased + "/") {
            return true
        }
        return false
    }
}
