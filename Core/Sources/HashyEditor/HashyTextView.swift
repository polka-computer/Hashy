#if canImport(AppKit)
import AppKit
import STTextView
import UniformTypeIdentifiers

/// STTextView subclass that handles image drag-and-drop and paste operations.
/// Images are saved via `imageSaveHandler` and markdown syntax is auto-inserted.
open class HashyTextView: STTextView {

    /// Called with (imageData, UTType, suggestedFilename).
    /// Returns the relative path to use in markdown, or nil on failure.
    public var imageSaveHandler: ((Data, UTType, String) -> String?)?

    override open var readablePasteboardTypes: [NSPasteboard.PasteboardType] {
        var types = super.readablePasteboardTypes
        types.append(contentsOf: [.fileURL, .png, .tiff])
        return types
    }

    // MARK: - Drag & Drop

    override open func draggingEntered(_ sender: any NSDraggingInfo) -> NSDragOperation {
        if pasteboardContainsImage(sender.draggingPasteboard) {
            return .copy
        }
        return super.draggingEntered(sender)
    }

    override open func draggingUpdated(_ sender: any NSDraggingInfo) -> NSDragOperation {
        if pasteboardContainsImage(sender.draggingPasteboard) {
            _ = super.draggingUpdated(sender)
            return .copy
        }
        return super.draggingUpdated(sender)
    }

    override open func performDragOperation(_ sender: any NSDraggingInfo) -> Bool {
        let pasteboard = sender.draggingPasteboard
        guard pasteboardContainsImage(pasteboard) else {
            return super.performDragOperation(sender)
        }
        guard let markdown = handleImagePasteboard(pasteboard) else {
            return false
        }
        insertImageMarkdown(markdown)
        return true
    }

    // MARK: - Paste

    @objc override open func paste(_ sender: Any?) {
        let pasteboard = NSPasteboard.general
        if pasteboardContainsImage(pasteboard),
           let markdown = handleImagePasteboard(pasteboard) {
            insertImageMarkdown(markdown)
            return
        }
        super.paste(sender)
    }

    // MARK: - Image Pasteboard Helpers

    private func pasteboardContainsImage(_ pasteboard: NSPasteboard) -> Bool {
        // Image file URLs are always prioritized (explicit user intent)
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [
            .urlReadingContentsConformToTypes: [UTType.image.identifier]
        ]) as? [URL], !urls.isEmpty {
            return true
        }

        // Raw image data only when no plain text is present
        // (copying text from browsers can include TIFF representations)
        if pasteboard.string(forType: .string) != nil {
            return false
        }

        for type in [NSPasteboard.PasteboardType.tiff, .png] {
            if pasteboard.data(forType: type) != nil {
                return true
            }
        }
        return false
    }

    private func handleImagePasteboard(_ pasteboard: NSPasteboard) -> String? {
        guard let handler = imageSaveHandler else { return nil }

        var snippets: [String] = []

        // Try image file URLs first
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [
            .urlReadingContentsConformToTypes: [UTType.image.identifier]
        ]) as? [URL] {
            for url in urls {
                guard let data = try? Data(contentsOf: url) else { continue }
                let ext = url.pathExtension.lowercased()
                let filename = "\(UUID().uuidString).\(ext.isEmpty ? "png" : ext)"
                let uti = UTType(filenameExtension: ext) ?? .png
                if let path = handler(data, uti, filename) {
                    snippets.append("![](\(path))")
                }
            }
        }

        // Fall back to raw image data
        if snippets.isEmpty {
            if let tiffData = pasteboard.data(forType: .tiff),
               let pngData = convertTIFFtoPNG(tiffData) {
                let filename = "\(UUID().uuidString).png"
                if let path = handler(pngData, .png, filename) {
                    snippets.append("![](\(path))")
                }
            } else if let pngData = pasteboard.data(forType: .png) {
                let filename = "\(UUID().uuidString).png"
                if let path = handler(pngData, .png, filename) {
                    snippets.append("![](\(path))")
                }
            }
        }

        guard !snippets.isEmpty else { return nil }
        return snippets.joined(separator: "\n")
    }

    private func convertTIFFtoPNG(_ tiffData: Data) -> Data? {
        guard let imageRep = NSBitmapImageRep(data: tiffData) else { return nil }
        return imageRep.representation(using: .png, properties: [:])
    }

    private func insertImageMarkdown(_ markdown: String) {
        var insertion = markdown

        if let text = self.text {
            let docStart = textContentManager.documentRange.location
            let cursorOffset: Int
            if let sel = textLayoutManager.textSelections.first,
               let selRange = sel.textRanges.first {
                cursorOffset = textContentManager.offset(from: docStart, to: selRange.location)
            } else {
                cursorOffset = text.count
            }

            // Ensure leading newline if not at start of line
            if cursorOffset > 0 {
                let idx = text.index(text.startIndex, offsetBy: cursorOffset - 1)
                if text[idx] != "\n" {
                    insertion = "\n" + insertion
                }
            }

            // Ensure trailing newline
            if cursorOffset < text.count {
                let idx = text.index(text.startIndex, offsetBy: cursorOffset)
                if text[idx] != "\n" {
                    insertion += "\n"
                }
            } else {
                insertion += "\n"
            }
        }

        // Insert at current selection; handles undo and triggers delegate callbacks
        insertText(insertion, replacementRange: NSRange(location: NSNotFound, length: 0))
    }
}

#elseif canImport(UIKit)
import UIKit
import STTextView
import UniformTypeIdentifiers

/// STTextView subclass that handles image paste operations on iOS.
/// Also provides `inputAccessoryView` and `UIKeyCommand` support.
open class HashyTextView: STTextView {

    /// Called with (imageData, UTType, suggestedFilename).
    /// Returns the relative path to use in markdown, or nil on failure.
    public var imageSaveHandler: ((Data, UTType, String) -> String?)?

    /// Handler for hardware keyboard shortcuts (Cmd+B, Cmd+I, Cmd+Return)
    public var keyCommandHandler: ((UIKeyCommand) -> Void)?

    // MARK: - Input Accessory View

    /// Backing storage for the keyboard accessory toolbar.
    var customInputAccessoryView: UIView?

    override open var inputAccessoryView: UIView? {
        customInputAccessoryView
    }

    // MARK: - Key Commands (hardware keyboard)

    override open var keyCommands: [UIKeyCommand]? {
        var commands = super.keyCommands ?? []
        commands.append(contentsOf: [
            UIKeyCommand(input: "b", modifierFlags: .command, action: #selector(handleKeyCommand(_:))),
            UIKeyCommand(input: "i", modifierFlags: .command, action: #selector(handleKeyCommand(_:))),
            UIKeyCommand(input: "\r", modifierFlags: .command, action: #selector(handleKeyCommand(_:))),
        ])
        return commands
    }

    @objc private func handleKeyCommand(_ command: UIKeyCommand) {
        keyCommandHandler?(command)
    }

    // MARK: - Paste (image handling)

    override open func paste(_ sender: Any?) {
        let pasteboard = UIPasteboard.general
        if pasteboardContainsImage(pasteboard),
           let markdown = handleImagePasteboard(pasteboard) {
            insertImageMarkdown(markdown)
            return
        }
        super.paste(sender)
    }

    private func pasteboardContainsImage(_ pasteboard: UIPasteboard) -> Bool {
        // Only treat as image paste when no plain text is present
        if pasteboard.hasStrings { return false }
        return pasteboard.hasImages
    }

    private func handleImagePasteboard(_ pasteboard: UIPasteboard) -> String? {
        guard let handler = imageSaveHandler else { return nil }

        if let image = pasteboard.image,
           let pngData = image.pngData() {
            let filename = "\(UUID().uuidString).png"
            if let path = handler(pngData, .png, filename) {
                return "![](\(path))"
            }
        }
        return nil
    }

    private func insertImageMarkdown(_ markdown: String) {
        var insertion = markdown

        if let text = self.text {
            let docStart = textContentManager.documentRange.location
            let cursorOffset: Int
            if let sel = textLayoutManager.textSelections.first,
               let selRange = sel.textRanges.first {
                cursorOffset = textContentManager.offset(from: docStart, to: selRange.location)
            } else {
                cursorOffset = text.count
            }

            // Ensure leading newline if not at start of line
            if cursorOffset > 0 {
                let idx = text.index(text.startIndex, offsetBy: cursorOffset - 1)
                if text[idx] != "\n" {
                    insertion = "\n" + insertion
                }
            }

            // Ensure trailing newline
            if cursorOffset < text.count {
                let idx = text.index(text.startIndex, offsetBy: cursorOffset)
                if text[idx] != "\n" {
                    insertion += "\n"
                }
            } else {
                insertion += "\n"
            }
        }

        insertText(insertion, replacementRange: NSRange(location: NSNotFound, length: 0))
    }
}
#endif
