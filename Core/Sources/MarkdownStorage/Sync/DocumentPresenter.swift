import Foundation
import OSLog

/// NSFilePresenter for the currently edited file.
/// Monitors external changes, moves, deletions, and version conflicts.
/// Only one file is presented at a time — swap via `present(url:)`.
public final class DocumentPresenter: NSObject, NSFilePresenter, @unchecked Sendable {
    /// Called when the presented file's content changes externally.
    public var onContentDidChange: (@Sendable (URL) -> Void)?

    /// Called when the presented file is moved to a new URL.
    public var onDidMove: (@Sendable (URL) -> Void)?

    /// Called when the presented file is deleted (or evicted from iCloud).
    public var onDeleted: (@Sendable () -> Void)?

    private var _presentedItemURL: URL?
    private let _operationQueue = OperationQueue()
    private let lock = NSLock()
    private let logger = Logger(subsystem: "ca.long.tail.labs.hashy", category: "DocumentPresenter")

    public var presentedItemURL: URL? {
        lock.lock()
        defer { lock.unlock() }
        return _presentedItemURL
    }

    public var presentedItemOperationQueue: OperationQueue {
        _operationQueue
    }

    public override init() {
        _operationQueue.maxConcurrentOperationCount = 1
        _operationQueue.qualityOfService = .userInitiated
        super.init()
    }

    /// Start presenting (watching) the given file URL.
    /// Resigns any previously presented file first.
    public func present(url: URL) {
        resign()
        lock.lock()
        _presentedItemURL = url
        lock.unlock()
        NSFileCoordinator.addFilePresenter(self)
        logger.debug("Presenting file for external change monitoring: \(url.path, privacy: .public)")
    }

    /// Stop presenting the current file.
    public func resign() {
        lock.lock()
        let hasURL = _presentedItemURL != nil
        if hasURL {
            _presentedItemURL = nil
        }
        lock.unlock()
        if hasURL {
            NSFileCoordinator.removeFilePresenter(self)
            logger.debug("Stopped presenting file")
        }
    }

    // MARK: - NSFilePresenter

    public func presentedItemDidChange() {
        guard let url = presentedItemURL else { return }
        logger.debug("Presented file changed externally: \(url.path, privacy: .public)")
        onContentDidChange?(url)
    }

    public func presentedItemDidMove(to newURL: URL) {
        lock.lock()
        _presentedItemURL = newURL
        lock.unlock()
        logger.debug("Presented file moved: \(newURL.path, privacy: .public)")
        onDidMove?(newURL)
    }

    public func accommodatePresentedItemDeletion(completionHandler: @escaping @Sendable (Error?) -> Void) {
        logger.debug("Presented file deleted or evicted")
        onDeleted?()
        completionHandler(nil)
    }

    public func presentedItemDidGain(_ version: NSFileVersion) {
        guard let url = presentedItemURL else { return }
        logger.debug("Presented file gained new version: \(url.path, privacy: .public)")
        onContentDidChange?(url)
    }
}
