import Foundation

/// Thread-safe file I/O using NSFileCoordinator for iCloud compatibility.
public enum FileCoordinatorIO {
    /// Read the contents of a file using coordinated access.
    public static func readData(at url: URL) throws -> Data {
        var coordinatorError: NSError?
        var readError: Error?
        var result: Data?

        let coordinator = NSFileCoordinator()
        coordinator.coordinate(readingItemAt: url, options: [], error: &coordinatorError) { coordinatedURL in
            do {
                result = try Data(contentsOf: coordinatedURL)
            } catch {
                readError = error
            }
        }

        if let coordinatorError { throw coordinatorError }
        if let readError { throw readError }
        guard let result else { throw CocoaError(.fileReadUnknown) }
        return result
    }

    /// Read a file's content as a string.
    public static func readString(at url: URL, encoding: String.Encoding = .utf8) throws -> String {
        let data = try readData(at: url)
        guard let string = String(data: data, encoding: encoding) else {
            throw CocoaError(.fileReadInapplicableStringEncoding)
        }
        return string
    }

    /// Write data to a file using coordinated access.
    public static func writeData(_ data: Data, to url: URL) throws {
        var coordinatorError: NSError?
        var writeError: Error?

        // Capture original creation date before writing (atomic writes reset it)
        let originalCreationDate = try? url.resourceValues(forKeys: [.creationDateKey]).creationDate

        let coordinator = NSFileCoordinator()
        coordinator.coordinate(writingItemAt: url, options: .forReplacing, error: &coordinatorError) { coordinatedURL in
            do {
                try data.write(to: coordinatedURL, options: .atomic)
                // Restore original creation date (atomic writes replace the file, resetting it)
                if let creationDate = originalCreationDate {
                    var resourceValues = URLResourceValues()
                    resourceValues.creationDate = creationDate
                    var mutableURL = coordinatedURL
                    try? mutableURL.setResourceValues(resourceValues)
                }
            } catch {
                writeError = error
            }
        }

        if let coordinatorError { throw coordinatorError }
        if let writeError { throw writeError }
    }

    /// Write a string to a file.
    public static func writeString(_ string: String, to url: URL, encoding: String.Encoding = .utf8) throws {
        guard let data = string.data(using: encoding) else {
            throw CocoaError(.fileWriteInapplicableStringEncoding)
        }
        try writeData(data, to: url)
    }

    /// Delete a file using coordinated access.
    public static func delete(at url: URL) throws {
        var coordinatorError: NSError?
        var deleteError: Error?

        let coordinator = NSFileCoordinator()
        coordinator.coordinate(writingItemAt: url, options: .forDeleting, error: &coordinatorError) { coordinatedURL in
            do {
                try FileManager.default.removeItem(at: coordinatedURL)
            } catch {
                deleteError = error
            }
        }

        if let coordinatorError { throw coordinatorError }
        if let deleteError { throw deleteError }
    }

    /// Move/rename a file using coordinated access.
    public static func move(from sourceURL: URL, to destinationURL: URL) throws {
        var coordinatorError: NSError?
        var moveError: Error?

        let coordinator = NSFileCoordinator()
        coordinator.coordinate(
            writingItemAt: sourceURL, options: .forMoving,
            writingItemAt: destinationURL, options: .forReplacing,
            error: &coordinatorError
        ) { coordSource, coordDest in
            do {
                try FileManager.default.moveItem(at: coordSource, to: coordDest)
            } catch {
                moveError = error
            }
        }

        if let coordinatorError { throw coordinatorError }
        if let moveError { throw moveError }
    }
}
