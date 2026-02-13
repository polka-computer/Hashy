import SwiftUI
@_exported import STTextView

#if canImport(AppKit)
import AppKit
import Quartz

// MARK: - macOS Hashy Editor View

/// A native TextKit 2 markdown editor with wiki-link chip support.
/// Uses STTextView (TextKit 2) for performant text editing with
/// syntax highlighting and inline wiki-link styling.
public struct HashyEditorView: NSViewRepresentable {
    @Binding public var text: String
    public var font: NSFont
    public var textColor: NSColor
    public var backgroundColor: NSColor
    public var isEditable: Bool
    public var showLineNumbers: Bool
    public var showOverlayButtons: Bool
    public var wikiLinkResolver: WikiLinkResolver?
    public var completionProvider: ((String) -> [HashyCompletionResult])?
    public var onEmbedTrigger: ((WikiLinkInsertion.Trigger) -> Void)?
    public var onLinkClicked: ((String) -> Void)?
    public var onTextChange: ((String) -> Void)?
    public var onOverlayButtonTapped: ((OverlayItem) -> Void)?
    public var imageBaseURL: URL?
    public var focusTrigger: Int = 0

    public init(
        text: Binding<String>,
        font: NSFont = .monospacedSystemFont(ofSize: 13, weight: .regular),
        textColor: NSColor = .white.withAlphaComponent(0.92),
        backgroundColor: NSColor = .black,
        isEditable: Bool = true,
        showLineNumbers: Bool = false,
        showOverlayButtons: Bool = false,
        wikiLinkResolver: WikiLinkResolver? = nil,
        completionProvider: ((String) -> [HashyCompletionResult])? = nil,
        onEmbedTrigger: ((WikiLinkInsertion.Trigger) -> Void)? = nil,
        onLinkClicked: ((String) -> Void)? = nil,
        onTextChange: ((String) -> Void)? = nil,
        onOverlayButtonTapped: ((OverlayItem) -> Void)? = nil,
        imageBaseURL: URL? = nil,
        focusTrigger: Int = 0
    ) {
        self._text = text
        self.font = font
        self.textColor = textColor
        self.backgroundColor = backgroundColor
        self.isEditable = isEditable
        self.showLineNumbers = showLineNumbers
        self.showOverlayButtons = showOverlayButtons
        self.wikiLinkResolver = wikiLinkResolver
        self.completionProvider = completionProvider
        self.onEmbedTrigger = onEmbedTrigger
        self.onLinkClicked = onLinkClicked
        self.onTextChange = onTextChange
        self.onOverlayButtonTapped = onOverlayButtonTapped
        self.imageBaseURL = imageBaseURL
        self.focusTrigger = focusTrigger
    }

    public func makeNSView(context: Context) -> NSScrollView {
        let scrollView = HashyTextView.scrollableTextView()
        guard let textView = scrollView.documentView as? HashyTextView else {
            return scrollView
        }

        configureTextView(textView)
        textView.isIncrementalSearchingEnabled = true
        let coordinator = context.coordinator
        textView.textDelegate = coordinator
        coordinator.textView = textView
        coordinator.parent = self

        // Add overlay plugin if enabled
        if showOverlayButtons {
            let overlayPlugin = HashyOverlayPlugin(delegate: coordinator)
            coordinator.overlayPlugin = overlayPlugin
            textView.addPlugin(overlayPlugin)
        }

        // Wire image save handler for drag-and-drop / paste
        textView.imageSaveHandler = { [weak coordinator] data, _, filename in
            coordinator?.saveDroppedImage(data: data, filename: filename)
        }

        // Set initial content with proper base attributes
        coordinator.setTextWithBaseAttributes(text)

        // Key monitor for editor shortcuts
        coordinator.keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak textView, weak coordinator] event in
            guard let textView = textView, let coordinator = coordinator,
                  textView.window?.firstResponder === textView else { return event }
            let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            let key = event.charactersIgnoringModifiers?.lowercased()

            // Letter-based shortcuts (layout-independent via charactersIgnoringModifiers)
            if mods == .command {
                switch key {
                case "b": coordinator.handleBold(); return nil
                case "i": coordinator.handleItalic(); return nil
                case "f": textView.textFinder.performAction(.showFindInterface); return nil
                default: break
                }
            }

            // Key-code shortcuts (non-character keys, layout-independent)
            switch (mods, event.keyCode) {
            case (.command, 36):    coordinator.handleCmdReturn(); return nil
            case (let m, 48) where m.isEmpty || m == .function:
                coordinator.handleIndent(); return nil
            case (.shift, 48):      coordinator.handleOutdent(); return nil
            default: return event
            }
        }

        scrollView.hasHorizontalScroller = false
        scrollView.backgroundColor = backgroundColor
        scrollView.drawsBackground = true

        return scrollView
    }

    public func sizeThatFits(_ proposal: ProposedViewSize, nsView: NSScrollView, context: Context) -> CGSize? {
        // Always accept the proposed size so content length never shifts the layout.
        CGSize(width: proposal.width ?? 400, height: proposal.height ?? 400)
    }

    public func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? HashyTextView else { return }
        context.coordinator.parent = self

        if !context.coordinator.isInternalUpdate && textView.text != text {
            context.coordinator.isInternalUpdate = true
            context.coordinator.setTextWithBaseAttributes(text)
            context.coordinator.isInternalUpdate = false
        }

        textView.isEditable = isEditable

        if context.coordinator.lastFocusTrigger != focusTrigger {
            context.coordinator.lastFocusTrigger = focusTrigger
            // Async: the view may not be in a window yet during initial updateNSView
            DispatchQueue.main.async {
                textView.window?.makeFirstResponder(textView)
                // Move cursor to end of document
                let docEnd = textView.textContentManager.documentRange.endLocation
                let endRange = NSTextRange(location: docEnd)
                textView.textLayoutManager.textSelections = [
                    NSTextSelection(range: endRange, affinity: .downstream, granularity: .character)
                ]
                textView.needsLayout = true
            }
        }
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    private func configureTextView(_ textView: STTextView) {
        textView.font = font
        textView.textColor = textColor
        textView.backgroundColor = backgroundColor
        textView.isEditable = isEditable
        textView.showsLineNumbers = showLineNumbers
        textView.highlightSelectedLine = true
        textView.isHorizontallyResizable = false

        // Line spacing via defaultParagraphStyle
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineHeightMultiple = 1.4
        paragraph.defaultTabInterval = 28
        textView.defaultParagraphStyle = paragraph
    }

    // MARK: - Coordinator

    public class Coordinator: NSObject, STTextViewDelegate, OverlayButtonDelegate, QLPreviewPanelDataSource {
        var parent: HashyEditorView
        weak var textView: STTextView?
        var isInternalUpdate = false
        var keyMonitor: Any?
        var overlayPlugin: HashyOverlayPlugin?
        var lastFocusTrigger: Int = 0

        /// Tracks checkbox ranges for click detection
        private var checkboxRanges: [(nsRange: NSRange, isChecked: Bool)] = []

        /// Tracks whether we're in @-mention completion mode
        private var isMentionMode = false

        /// Image overlay views keyed by character offset of `!`
        private var imageViews: [Int: NSImageView] = [:]
        /// Resolved URLs keyed by character offset (for Quick Look)
        private var imageURLs: [Int: URL] = [:]
        /// Loaded image cache keyed by resolved URL string
        private var imageCache: [String: NSImage] = [:]
        /// URLs currently being fetched (prevents duplicate downloads)
        private var imageFetchesInFlight: Set<String> = []
        /// URL currently shown in Quick Look
        private var previewURL: URL?

        init(_ parent: HashyEditorView) {
            self.parent = parent
        }

        // MARK: - OverlayButtonDelegate

        public func overlayButtonTapped(item: OverlayItem) {
            parent.onOverlayButtonTapped?(item)
        }

        deinit {
            if let monitor = keyMonitor {
                NSEvent.removeMonitor(monitor)
            }
            if QLPreviewPanel.sharedPreviewPanelExists(),
               let panel = QLPreviewPanel.shared() {
                if panel.dataSource === self {
                    panel.dataSource = nil
                }
            }
            for (_, view) in imageViews {
                view.removeFromSuperview()
            }
        }

        // MARK: - Image Drop/Paste

        func saveDroppedImage(data: Data, filename: String) -> String? {
            guard let baseURL = parent.imageBaseURL else { return nil }
            let assetsURL = baseURL.appendingPathComponent("_assets")
            do {
                try FileManager.default.createDirectory(at: assetsURL, withIntermediateDirectories: true)
                let fileURL = assetsURL.appendingPathComponent(filename)
                try data.write(to: fileURL, options: .atomic)
                return "_assets/\(filename)"
            } catch {
                return nil
            }
        }

        // MARK: - Text Change Handling

        public func textViewDidChangeText(_ notification: Notification) {
            guard !isInternalUpdate else { return }
            guard let textView = textView else { return }

            isInternalUpdate = true

            let newText = textView.text ?? ""
            parent.text = newText
            parent.onTextChange?(newText)

            // Re-apply highlighting after change
            applyHighlighting()

            isInternalUpdate = false

            // If in mention mode, refresh completion on each keystroke
            if isMentionMode {
                DispatchQueue.main.async {
                    textView.complete(nil)
                }
            }
        }

        /// Detects @ and [[ triggers at the actual cursor position
        public func textView(_ textView: STTextView, didChangeTextIn affectedCharRange: NSTextRange, replacementString: String) {
            guard !isInternalUpdate else { return }

            let text = textView.text ?? ""
            let docStart = textView.textContentManager.documentRange.location
            let endOffset = textView.textContentManager.offset(from: docStart, to: affectedCharRange.endLocation)

            // Detect @ trigger (after whitespace or at line start)
            if replacementString == "@" {
                let startOffset = textView.textContentManager.offset(from: docStart, to: affectedCharRange.location)
                if startOffset == 0 || charBefore(offset: startOffset, in: text)?.isWhitespace == true || charBefore(offset: startOffset, in: text)?.isNewline == true {
                    isMentionMode = true
                    parent.onEmbedTrigger?(.mention)
                    DispatchQueue.main.async {
                        textView.complete(nil)
                    }
                }
            }

            // Detect [[ trigger
            let insertEnd = endOffset + replacementString.count
            if replacementString == "[" && insertEnd >= 2 {
                let startIdx = text.index(text.startIndex, offsetBy: insertEnd - 2, limitedBy: text.endIndex)
                let endIdx = text.index(text.startIndex, offsetBy: insertEnd, limitedBy: text.endIndex)
                if let startIdx, let endIdx, String(text[startIdx..<endIdx]) == "[[" {
                    isMentionMode = true
                    parent.onEmbedTrigger?(.wikiLink)
                    DispatchQueue.main.async {
                        textView.complete(nil)
                    }
                }
            }

            // Exit mention mode on space or newline
            if isMentionMode && (replacementString == " " || replacementString == "\n") {
                isMentionMode = false
                textView.cancelComplete(nil)
            }

            // List continuation: when Enter is pressed, continue list prefix
            if replacementString == "\n" {
                handleListContinuation(textView: textView, text: text, insertOffset: insertEnd)
            }
        }

        // MARK: - List Continuation

        private func handleListContinuation(textView: STTextView, text: String, insertOffset: Int) {
            let cursorIdx = text.index(text.startIndex, offsetBy: min(insertOffset, text.count))
            let textBeforeCursor = String(text[..<cursorIdx])

            let lines = textBeforeCursor.components(separatedBy: "\n")
            guard lines.count >= 2 else { return }
            let previousLine = lines[lines.count - 2]

            // Detect list prefix
            let prefix: String?
            if previousLine.hasPrefix("- [x] ") || previousLine.hasPrefix("- [X] ") {
                prefix = "- [ ] "
            } else if previousLine.hasPrefix("- [ ] ") {
                prefix = "- [ ] "
            } else if previousLine.hasPrefix("- ") {
                prefix = "- "
            } else if previousLine.hasPrefix("* ") {
                prefix = "* "
            } else {
                prefix = nil
            }

            guard let listPrefix = prefix else { return }

            let contentAfterPrefix: String
            if previousLine.hasPrefix("- [x] ") || previousLine.hasPrefix("- [X] ") || previousLine.hasPrefix("- [ ] ") {
                contentAfterPrefix = String(previousLine.dropFirst(6))
            } else {
                contentAfterPrefix = String(previousLine.dropFirst(2))
            }

            if contentAfterPrefix.trimmingCharacters(in: .whitespaces).isEmpty {
                let prefixStart = insertOffset - 1 - previousLine.count
                guard prefixStart >= 0 else { return }
                let removeStart = text.index(text.startIndex, offsetBy: prefixStart)
                let removeEnd = text.index(text.startIndex, offsetBy: min(insertOffset, text.count))
                var newText = text
                newText.replaceSubrange(removeStart..<removeEnd, with: "\n")

                isInternalUpdate = true
                textView.text = newText
                parent.text = newText
                parent.onTextChange?(newText)
                applyHighlighting()
                isInternalUpdate = false

                let newCursorOffset = prefixStart + 1
                setCursorPosition(in: textView, offset: newCursorOffset)
            } else {
                var newText = text
                let insertIdx = text.index(text.startIndex, offsetBy: min(insertOffset, text.count))
                newText.insert(contentsOf: listPrefix, at: insertIdx)

                isInternalUpdate = true
                textView.text = newText
                parent.text = newText
                parent.onTextChange?(newText)
                applyHighlighting()
                isInternalUpdate = false

                let newCursorOffset = insertOffset + listPrefix.count
                setCursorPosition(in: textView, offset: newCursorOffset)
            }
        }

        private func setCursorPosition(in textView: STTextView, offset: Int) {
            let docStart = textView.textContentManager.documentRange.location
            guard let targetLocation = textView.textContentManager.location(docStart, offsetBy: offset) else { return }
            let targetRange = NSTextRange(location: targetLocation)
            textView.textLayoutManager.textSelections = [
                NSTextSelection(range: targetRange, affinity: .downstream, granularity: .character)
            ]
            textView.needsLayout = true
        }

        // MARK: - Completion (@ and [[ autocomplete)

        public func textView(_ textView: STTextView, completionItemsAtLocation location: any NSTextLocation) -> [any STCompletionItem]? {
            guard isMentionMode else { return nil }
            guard let text = textView.text else { return nil }

            let docStart = textView.textContentManager.documentRange.location
            let cursorOffset = textView.textContentManager.offset(from: docStart, to: location)
            let textUpToCursor = String(text.prefix(cursorOffset))

            let query: String
            let trigger: WikiLinkInsertion.Trigger
            if let atIdx = textUpToCursor.lastIndex(of: "@"),
               (atIdx == textUpToCursor.startIndex || textUpToCursor[textUpToCursor.index(before: atIdx)].isWhitespace) {
                query = String(textUpToCursor[textUpToCursor.index(after: atIdx)...])
                trigger = .mention
            } else if let bracketRange = textUpToCursor.range(of: "[[", options: .backwards) {
                query = String(textUpToCursor[bracketRange.upperBound...])
                trigger = .wikiLink
            } else {
                return nil
            }

            let results: [HashyCompletionResult]
            if let provider = parent.completionProvider {
                results = provider(query)
            } else {
                results = Self.demoResults.filter { result in
                    query.isEmpty || result.title.localizedCaseInsensitiveContains(query)
                }
            }

            guard !results.isEmpty else { return nil }

            return results.prefix(8).map { result in
                HashyCompletionItemView(result: result, trigger: trigger)
            }
        }

        public func textView(_ textView: STTextView, insertCompletionItem item: any STCompletionItem) {
            guard let hashyItem = item as? HashyCompletionItemView else { return }
            guard var text = textView.text else { return }

            guard let insertionPoint = textView.textLayoutManager.insertionPointLocations.first else { return }
            let docStart = textView.textContentManager.documentRange.location
            let cursorOffset = textView.textContentManager.offset(from: docStart, to: insertionPoint)
            let textUpToCursor = String(text.prefix(cursorOffset))

            let triggerStart: String.Index?
            switch hashyItem.trigger {
            case .mention:
                triggerStart = textUpToCursor.lastIndex(of: "@")
            case .wikiLink:
                if let range = textUpToCursor.range(of: "[[", options: .backwards) {
                    triggerStart = range.lowerBound
                } else {
                    triggerStart = nil
                }
            }

            guard let triggerStart else { return }

            let triggerOffset = text.distance(from: text.startIndex, to: triggerStart)
            let replaceStart = text.index(text.startIndex, offsetBy: triggerOffset)
            let replaceEnd = text.index(text.startIndex, offsetBy: cursorOffset)
            let wikiLink = "[[\(hashyItem.result.id)|\(hashyItem.result.title)]]"
            text.replaceSubrange(replaceStart..<replaceEnd, with: wikiLink)

            isInternalUpdate = true
            textView.text = text
            parent.text = text
            parent.onTextChange?(text)
            applyHighlighting()
            isInternalUpdate = false

            isMentionMode = false
        }

        private static let demoResults: [HashyCompletionResult] = [
            HashyCompletionResult(id: "project-alpha", title: "Project Alpha", icon: "folder", typeName: "Project"),
            HashyCompletionResult(id: "meeting-standup", title: "Daily Standup", icon: "calendar", typeName: "Meeting"),
            HashyCompletionResult(id: "note-ideas", title: "Product Ideas", icon: "lightbulb", typeName: "Note"),
            HashyCompletionResult(id: "person-jordan", title: "Jordan", icon: "person", typeName: "Person"),
            HashyCompletionResult(id: "book-designing", title: "Designing Data-Intensive Apps", icon: "book", typeName: "Book"),
            HashyCompletionResult(id: "task-ship-v1", title: "Ship v1.0", icon: "checkmark.circle", typeName: "Task"),
        ]

        private func charBefore(offset: Int, in text: String) -> Character? {
            guard offset > 0 else { return nil }
            let idx = text.index(text.startIndex, offsetBy: offset - 1, limitedBy: text.endIndex)
            guard let idx else { return nil }
            return text[idx]
        }

        // MARK: - Link Click Handling (Checkboxes + Wiki-Links)

        public func textView(_ textView: STTextView, clickedOnLink link: Any, at location: any NSTextLocation) -> Bool {
            guard let linkString = link as? String else { return false }

            if linkString.hasPrefix("hashy-todo://") {
                let offsetStr = linkString.replacingOccurrences(of: "hashy-todo://", with: "")
                if let offset = Int(offsetStr) {
                    toggleCheckbox(at: offset)
                }
                return true
            }

            if linkString.hasPrefix("hashy-link://") {
                let objectId = linkString.replacingOccurrences(of: "hashy-link://", with: "")
                parent.onLinkClicked?(objectId)
                return true
            }

            if linkString.hasPrefix("hashy-url://") {
                let urlString = linkString.replacingOccurrences(of: "hashy-url://", with: "")
                if let url = URL(string: urlString) {
                    NSWorkspace.shared.open(url)
                }
                return true
            }

            return false
        }

        private func toggleCheckbox(at offset: Int) {
            guard let textView = textView, var text = textView.text else { return }
            guard offset + 5 <= text.count else { return }

            let checkStart = text.index(text.startIndex, offsetBy: offset)
            let checkEnd = text.index(checkStart, offsetBy: 5)
            let current = String(text[checkStart..<checkEnd])

            let replacement: String
            if current == "- [ ]" {
                replacement = "- [x]"
            } else if current == "- [x]" || current == "- [X]" {
                replacement = "- [ ]"
            } else {
                return
            }

            text.replaceSubrange(checkStart..<checkEnd, with: replacement)

            isInternalUpdate = true
            textView.text = text
            parent.text = text
            parent.onTextChange?(text)
            applyHighlighting()
            isInternalUpdate = false
        }

        // MARK: - Cmd+Return Todo Toggle

        func handleCmdReturn() {
            guard let textView = textView, var text = textView.text else { return }

            let docStart = textView.textContentManager.documentRange.location
            guard let sel = textView.textLayoutManager.textSelections.first,
                  let selRange = sel.textRanges.first else { return }
            let cursorOffset = textView.textContentManager.offset(from: docStart, to: selRange.location)

            let nsText = text as NSString
            let lineRange = nsText.lineRange(for: NSRange(location: cursorOffset, length: 0))
            let line = nsText.substring(with: lineRange)

            let newLine: String
            if line.hasPrefix("- [ ] ") {
                newLine = "- [x] " + String(line.dropFirst(6))
            } else if line.hasPrefix("- [x] ") || line.hasPrefix("- [X] ") {
                newLine = "- [ ] " + String(line.dropFirst(6))
            } else if line.hasPrefix("- ") {
                newLine = "- [ ] " + String(line.dropFirst(2))
            } else {
                newLine = "- [ ] " + line
            }

            let replaceStart = text.index(text.startIndex, offsetBy: lineRange.location)
            let replaceEnd = text.index(replaceStart, offsetBy: lineRange.length)
            text.replaceSubrange(replaceStart..<replaceEnd, with: newLine)

            let lengthDelta = newLine.count - line.count
            let newCursorOffset = cursorOffset + lengthDelta

            isInternalUpdate = true
            textView.text = text
            parent.text = text
            parent.onTextChange?(text)
            applyHighlighting()
            isInternalUpdate = false

            setCursorPosition(in: textView, offset: max(lineRange.location, newCursorOffset))
        }

        // MARK: - Editor Helpers

        private struct SelectionInfo {
            let start: Int
            let end: Int
            var hasSelection: Bool { start != end }
        }

        private func getSelection(in textView: STTextView) -> SelectionInfo? {
            let docStart = textView.textContentManager.documentRange.location
            guard let sel = textView.textLayoutManager.textSelections.first,
                  let selRange = sel.textRanges.first else { return nil }
            let start = textView.textContentManager.offset(from: docStart, to: selRange.location)
            let end = textView.textContentManager.offset(from: docStart, to: selRange.endLocation)
            return SelectionInfo(start: start, end: end)
        }

        private func setSelectionRange(in textView: STTextView, start: Int, end: Int) {
            let docStart = textView.textContentManager.documentRange.location
            guard let startLoc = textView.textContentManager.location(docStart, offsetBy: start),
                  let endLoc = textView.textContentManager.location(docStart, offsetBy: end),
                  let range = NSTextRange(location: startLoc, end: endLoc) else { return }
            textView.textLayoutManager.textSelections = [
                NSTextSelection(range: range, affinity: .downstream, granularity: .character)
            ]
            textView.needsLayout = true
        }

        private func commitText(_ text: String) {
            guard let textView = textView else { return }
            isInternalUpdate = true
            parent.text = text
            parent.onTextChange?(text)
            setTextWithBaseAttributes(text)
            isInternalUpdate = false
        }

        private func lineRanges(in text: String, from start: Int, to end: Int) -> [NSRange] {
            let nsText = text as NSString
            var ranges: [NSRange] = []
            var pos = start
            while pos <= end && pos < nsText.length {
                let lineRange = nsText.lineRange(for: NSRange(location: pos, length: 0))
                ranges.append(lineRange)
                let next = lineRange.location + lineRange.length
                if next <= pos { break }
                pos = next
            }
            return ranges
        }

        // MARK: - Formatting Shortcuts

        func handleBold() {
            wrapSelection(prefix: "**", suffix: "**")
        }

        func handleItalic() {
            wrapSelection(prefix: "*", suffix: "*")
        }

        private func wrapSelection(prefix: String, suffix: String) {
            guard let textView = textView, let text = textView.text else { return }
            guard let sel = getSelection(in: textView) else { return }
            var newText = text
            if sel.hasSelection {
                let startIdx = text.index(text.startIndex, offsetBy: sel.start)
                let endIdx = text.index(text.startIndex, offsetBy: sel.end)
                let selected = String(text[startIdx..<endIdx])
                newText.replaceSubrange(startIdx..<endIdx, with: "\(prefix)\(selected)\(suffix)")
                commitText(newText)
                setSelectionRange(in: textView, start: sel.start + prefix.count, end: sel.start + prefix.count + selected.count)
            } else {
                let insertIdx = text.index(text.startIndex, offsetBy: sel.start)
                newText.insert(contentsOf: "\(prefix)\(suffix)", at: insertIdx)
                commitText(newText)
                setCursorPosition(in: textView, offset: sel.start + prefix.count)
            }
        }

        // MARK: - Indent/Outdent

        func handleIndent() {
            guard let textView = textView, let text = textView.text else { return }
            guard let sel = getSelection(in: textView) else { return }
            let effectiveEnd = sel.hasSelection ? max(sel.start, sel.end - 1) : sel.start
            let lines = lineRanges(in: text, from: sel.start, to: effectiveEnd)
            guard !lines.isEmpty else { return }
            var newText = text
            var insertedTotal = 0
            for lineRange in lines {
                let insertIdx = newText.index(newText.startIndex, offsetBy: lineRange.location + insertedTotal)
                newText.insert(contentsOf: "  ", at: insertIdx)
                insertedTotal += 2
            }
            commitText(newText)
            if sel.hasSelection {
                setSelectionRange(in: textView, start: sel.start + 2, end: sel.end + insertedTotal)
            } else {
                setCursorPosition(in: textView, offset: sel.start + 2)
            }
        }

        func handleOutdent() {
            guard let textView = textView, let text = textView.text else { return }
            guard let sel = getSelection(in: textView) else { return }
            let effectiveEnd = sel.hasSelection ? max(sel.start, sel.end - 1) : sel.start
            let lines = lineRanges(in: text, from: sel.start, to: effectiveEnd)
            guard !lines.isEmpty else { return }
            var newText = text
            var removedTotal = 0
            var firstLineRemoved = 0
            for (i, lineRange) in lines.enumerated() {
                let loc = lineRange.location - removedTotal
                let lineStartIdx = newText.index(newText.startIndex, offsetBy: loc)
                var spacesToRemove = 0
                var checkIdx = lineStartIdx
                while spacesToRemove < 2 && checkIdx < newText.endIndex && newText[checkIdx] == " " {
                    spacesToRemove += 1
                    checkIdx = newText.index(after: checkIdx)
                }
                if spacesToRemove > 0 {
                    newText.removeSubrange(lineStartIdx..<newText.index(lineStartIdx, offsetBy: spacesToRemove))
                    removedTotal += spacesToRemove
                    if i == 0 { firstLineRemoved = spacesToRemove }
                }
            }
            guard removedTotal > 0 else { return }
            commitText(newText)
            if sel.hasSelection {
                setSelectionRange(in: textView, start: max(0, sel.start - firstLineRemoved), end: max(0, sel.end - removedTotal))
            } else {
                setCursorPosition(in: textView, offset: max(0, sel.start - firstLineRemoved))
            }
        }

        // MARK: - Text Setting

        /// Sets text on the text view as an NSAttributedString with proper base
        /// foreground color and font. This avoids the TextKit 2 race condition
        /// where setting plain text via `textView.text` can leave characters
        /// with the system default color (black) if layout hasn't completed
        /// before attributes are applied.
        func setTextWithBaseAttributes(_ text: String) {
            guard let textView = textView else { return }

            let paragraph = NSMutableParagraphStyle()
            paragraph.lineHeightMultiple = 1.4
            paragraph.defaultTabInterval = 28

            let baseAttrs: [NSAttributedString.Key: Any] = [
                .foregroundColor: parent.textColor,
                .font: parent.font,
                .paragraphStyle: paragraph,
            ]

            let attrString = NSAttributedString(string: text, attributes: baseAttrs)

            if let contentStorage = textView.textContentManager as? NSTextContentStorage,
               let textStorage = contentStorage.textStorage {
                textStorage.setAttributedString(attrString)
            } else {
                // Fallback: set plain text
                textView.text = text
            }

            applyHighlighting()

            // Setting textStorage directly bypasses STTextView's viewport
            // invalidation pipeline. Two things are needed:
            // 1. ensureLayout computes geometry for the full document so the
            //    scroll view's content size is correct immediately.
            // 2. A deferred layoutViewport() re-creates fragment views once
            //    SwiftUI has finalized the scroll view's frame.
            textView.textLayoutManager.ensureLayout(for: textView.textContentManager.documentRange)
            DispatchQueue.main.async { [weak textView] in
                guard let textView else { return }
                textView.textLayoutManager.textViewportLayoutController.layoutViewport()
                textView.needsDisplay = true
            }
        }

        // MARK: - Image Rendering

        private func imageDisplaySize(for image: NSImage, in textView: STTextView) -> CGSize {
            let maxWidth = min(image.size.width, textView.bounds.width - 40)
            let maxHeight: CGFloat = 300
            let scale = min(maxWidth / max(image.size.width, 1), maxHeight / max(image.size.height, 1), 1.0)
            return CGSize(width: image.size.width * scale, height: image.size.height * scale)
        }

        private func resolveImageURL(_ pathString: String) -> URL? {
            if pathString.hasPrefix("https://") || pathString.hasPrefix("http://") {
                return URL(string: pathString)
            } else if pathString.hasPrefix("/") {
                return URL(fileURLWithPath: pathString)
            } else if pathString.hasPrefix("file://") {
                return URL(string: pathString)
            } else if let baseURL = parent.imageBaseURL {
                return baseURL.appendingPathComponent(pathString)
            }
            return nil
        }

        private func applyImageRendering(text: String, textView: STTextView) {
            let pattern = #"!\[([^\]]*)\]\(([^)]+)\)"#
            guard let regex = try? NSRegularExpression(pattern: pattern) else { return }

            let nsText = text as NSString
            let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))

            let dimAttrs: [NSAttributedString.Key: Any] = [
                .foregroundColor: NSColor.white.withAlphaComponent(0.3),
            ]

            var activeOffsets = Set<Int>()

            for match in matches {
                let fullRange = match.range
                let pathString = nsText.substring(with: match.range(at: 2))

                // Dim the full ![alt](path) syntax
                applyAttributes(dimAttrs, nsRange: fullRange, in: textView)

                guard let imageURL = resolveImageURL(pathString) else { continue }
                let cacheKey = imageURL.absoluteString
                let offset = fullRange.location

                // Determine which line this image syntax is on
                let lineRange = nsText.lineRange(for: NSRange(location: offset, length: 0))

                // Load image (from cache, disk, or network)
                if let cached = imageCache[cacheKey] {
                    activeOffsets.insert(offset)
                    let displaySize = imageDisplaySize(for: cached, in: textView)
                    applyParagraphSpacing(displaySize.height + 8, at: lineRange, in: textView)
                    positionImageView(image: cached, at: offset, url: imageURL, in: textView)
                    continue
                }

                if imageURL.isFileURL {
                    if let loaded = NSImage(contentsOf: imageURL) {
                        imageCache[cacheKey] = loaded
                        activeOffsets.insert(offset)
                        let displaySize = imageDisplaySize(for: loaded, in: textView)
                        applyParagraphSpacing(displaySize.height + 8, at: lineRange, in: textView)
                        positionImageView(image: loaded, at: offset, url: imageURL, in: textView)
                    }
                } else {
                    // Async fetch for HTTP(S) URLs
                    activeOffsets.insert(offset)
                    guard !imageFetchesInFlight.contains(cacheKey) else { continue }
                    imageFetchesInFlight.insert(cacheKey)
                    URLSession.shared.dataTask(with: imageURL) { [weak self] data, _, _ in
                        guard let data = data, let image = NSImage(data: data) else { return }
                        DispatchQueue.main.async {
                            guard let self = self, self.textView != nil else { return }
                            self.imageCache[cacheKey] = image
                            self.imageFetchesInFlight.remove(cacheKey)
                            self.applyHighlighting()
                        }
                    }.resume()
                }
            }

            // Remove stale image views
            for (offset, view) in imageViews where !activeOffsets.contains(offset) {
                view.removeFromSuperview()
                imageViews.removeValue(forKey: offset)
                imageURLs.removeValue(forKey: offset)
            }
        }

        private func applyParagraphSpacing(_ spacing: CGFloat, at lineRange: NSRange, in textView: STTextView) {
            let paragraph = NSMutableParagraphStyle()
            paragraph.lineHeightMultiple = 1.4
            paragraph.defaultTabInterval = 28
            paragraph.paragraphSpacing = spacing
            applyAttributes([.paragraphStyle: paragraph], nsRange: lineRange, in: textView)
        }

        private func positionImageView(image: NSImage, at offset: Int, url: URL, in textView: STTextView) {
            DispatchQueue.main.async { [weak self, weak textView] in
                guard let self = self, let textView = textView else { return }

                let textLayoutManager = textView.textLayoutManager
                let textContentManager = textView.textContentManager
                let docStart = textContentManager.documentRange.location

                guard let matchLocation = textContentManager.location(docStart, offsetBy: offset) else { return }

                var lineFrame: CGRect?
                textLayoutManager.enumerateTextLayoutFragments(
                    from: matchLocation,
                    options: [.ensuresLayout]
                ) { layoutFragment in
                    lineFrame = layoutFragment.layoutFragmentFrame
                    return false
                }

                guard let lineFrame = lineFrame else { return }

                let displaySize = self.imageDisplaySize(for: image, in: textView)

                // Position in the paragraph spacing gap (below text baseline, above next line)
                let imageFrame = CGRect(
                    x: lineFrame.minX,
                    y: lineFrame.maxY - displaySize.height - 4,
                    width: displaySize.width,
                    height: displaySize.height
                )

                self.imageURLs[offset] = url

                if let existingView = self.imageViews[offset] {
                    existingView.image = image
                    existingView.frame = imageFrame
                } else {
                    let imageView = NSImageView(frame: imageFrame)
                    imageView.image = image
                    imageView.imageScaling = .scaleProportionallyUpOrDown
                    imageView.wantsLayer = true
                    imageView.layer?.cornerRadius = 4
                    imageView.layer?.masksToBounds = true
                    let click = NSClickGestureRecognizer(target: self, action: #selector(self.imageViewClicked(_:)))
                    imageView.addGestureRecognizer(click)
                    textView.addSubview(imageView)
                    self.imageViews[offset] = imageView
                }
            }
        }

        // MARK: - Quick Look Preview

        @objc private func imageViewClicked(_ sender: NSClickGestureRecognizer) {
            guard let clickedView = sender.view else { return }
            guard let offset = imageViews.first(where: { $0.value === clickedView })?.key,
                  let url = imageURLs[offset] else { return }

            if url.isFileURL {
                previewURL = url
            } else {
                // Write cached image to temp file for Quick Look
                guard let image = imageCache[url.absoluteString],
                      let tiffData = image.tiffRepresentation,
                      let bitmapRep = NSBitmapImageRep(data: tiffData),
                      let pngData = bitmapRep.representation(using: .png, properties: [:]) else { return }
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString)
                    .appendingPathExtension("png")
                try? pngData.write(to: tempURL)
                previewURL = tempURL
            }

            guard let panel = QLPreviewPanel.shared() else { return }
            panel.dataSource = self
            panel.reloadData()
            panel.makeKeyAndOrderFront(nil)
        }

        public func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
            previewURL != nil ? 1 : 0
        }

        public func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> (any QLPreviewItem)! {
            previewURL as NSURL?
        }

        // MARK: - Highlighting

        func applyHighlighting() {
            guard let textView = textView else { return }
            guard let text = textView.text, !text.isEmpty else {
                // Clear all image views when text is empty
                for (_, view) in imageViews { view.removeFromSuperview() }
                imageViews.removeAll()
                return
            }

            // Reset base attributes on full range to clear stale .link, .underlineStyle, etc.
            let fullRange = NSRange(location: 0, length: (text as NSString).length)
            let paragraph = NSMutableParagraphStyle()
            paragraph.lineHeightMultiple = 1.4
            paragraph.defaultTabInterval = 28
            let baseAttrs: [NSAttributedString.Key: Any] = [
                .foregroundColor: parent.textColor,
                .font: parent.font,
                .paragraphStyle: paragraph,
            ]
            if let contentStorage = textView.textContentManager as? NSTextContentStorage,
               let textStorage = contentStorage.textStorage {
                textStorage.setAttributes(baseAttrs, range: fullRange)
            }

            checkboxRanges = []
            applyWikiLinkStyling(text: text, textView: textView)
            applyMarkdownStyling(text: text, textView: textView)
            applyImageRendering(text: text, textView: textView)
        }

        private func applyWikiLinkStyling(text: String, textView: STTextView) {
            let pattern = #"\[\[([^\]|]+)(?:\|([^\]]+))?\]\]"#
            guard let regex = try? NSRegularExpression(pattern: pattern) else { return }

            let nsText = text as NSString
            let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))

            let hiddenFont = NSFont.monospacedSystemFont(ofSize: 0.01, weight: .regular)
            let hiddenAttrs: [NSAttributedString.Key: Any] = [
                .foregroundColor: NSColor.clear,
                .font: hiddenFont,
            ]

            for match in matches {
                let targetId = nsText.substring(with: match.range(at: 1))
                var displayText = targetId
                let hasDisplayName = match.range(at: 2).location != NSNotFound
                if hasDisplayName {
                    displayText = nsText.substring(with: match.range(at: 2))
                }
                if let resolver = parent.wikiLinkResolver {
                    let resolved = resolver.resolve(id: targetId)
                    if let title = resolved.title {
                        displayText = title
                    }
                }

                let fullRange = match.range

                // Opening [[ — hidden
                let openBrackets = NSRange(location: fullRange.location, length: 2)
                applyAttributes(hiddenAttrs, nsRange: openBrackets, in: textView)

                // Closing ]] — hidden
                let closeBrackets = NSRange(location: fullRange.location + fullRange.length - 2, length: 2)
                applyAttributes(hiddenAttrs, nsRange: closeBrackets, in: textView)

                if hasDisplayName {
                    let idAndPipeRange = NSRange(location: fullRange.location + 2, length: match.range(at: 1).length + 1)
                    applyAttributes(hiddenAttrs, nsRange: idAndPipeRange, in: textView)

                    let nameRange = match.range(at: 2)
                    let chipAttrs: [NSAttributedString.Key: Any] = [
                        .foregroundColor: NSColor(red: 0.45, green: 0.75, blue: 1.0, alpha: 1.0),
                        .backgroundColor: NSColor(red: 0.25, green: 0.4, blue: 0.6, alpha: 0.3),
                        .link: "hashy-link://\(targetId)",
                        .toolTip: displayText,
                    ]
                    applyAttributes(chipAttrs, nsRange: nameRange, in: textView)
                } else {
                    let idRange = match.range(at: 1)
                    let chipAttrs: [NSAttributedString.Key: Any] = [
                        .foregroundColor: NSColor(red: 0.45, green: 0.75, blue: 1.0, alpha: 1.0),
                        .backgroundColor: NSColor(red: 0.25, green: 0.4, blue: 0.6, alpha: 0.3),
                        .link: "hashy-link://\(targetId)",
                        .toolTip: displayText,
                    ]
                    applyAttributes(chipAttrs, nsRange: idRange, in: textView)
                }
            }
        }

        private func applyMarkdownStyling(text: String, textView: STTextView) {
            let nsText = text as NSString

            nsText.enumerateSubstrings(in: NSRange(location: 0, length: nsText.length), options: [.byLines, .substringNotRequired]) { _, range, _, _ in
                let line = nsText.substring(with: range)
                self.styleMarkdownLine(line, at: range, in: textView)
            }
        }

        private func styleMarkdownLine(_ line: String, at range: NSRange, in textView: STTextView) {
            // Headings
            let headingLevel = countLeadingHashes(line)
            if headingLevel > 0 && headingLevel <= 6 {
                let sizes: [CGFloat] = [20, 18, 16, 14.5, 13.5, 13]
                let weights: [NSFont.Weight] = [.bold, .bold, .semibold, .semibold, .medium, .medium]
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: NSFont.monospacedSystemFont(ofSize: sizes[headingLevel - 1], weight: weights[headingLevel - 1]),
                    .foregroundColor: NSColor.white.withAlphaComponent(0.95),
                ]
                applyAttributes(attrs, nsRange: range, in: textView)
                return
            }

            // Inline code `text`
            applyInlinePattern(#"`([^`]+)`"#, in: line, lineRange: range, textView: textView, attrs: [
                .foregroundColor: NSColor(red: 0.95, green: 0.75, blue: 0.25, alpha: 1.0),
                .backgroundColor: NSColor(white: 0.12, alpha: 1.0),
            ])

            // Bold **text**
            applyInlinePattern(#"\*\*(.+?)\*\*"#, in: line, lineRange: range, textView: textView, attrs: [
                .font: NSFont.monospacedSystemFont(ofSize: 13, weight: .bold),
                .foregroundColor: NSColor.white,
            ])

            // Italic *text*
            applyInlinePattern(#"(?<!\*)\*(?!\*)(.+?)(?<!\*)\*(?!\*)"#, in: line, lineRange: range, textView: textView, attrs: [
                .font: NSFont(descriptor: NSFont.monospacedSystemFont(ofSize: 13, weight: .regular).fontDescriptor.withSymbolicTraits(.italic), size: 13) ?? NSFont.monospacedSystemFont(ofSize: 13, weight: .regular),
                .obliqueness: 0.25 as NSNumber,
                .foregroundColor: NSColor.white.withAlphaComponent(0.80),
            ])

            // Blockquote > text
            if line.hasPrefix(">") {
                applyAttributes([
                    .foregroundColor: NSColor.white.withAlphaComponent(0.6),
                ], nsRange: range, in: textView)
            }

            // Todo checkboxes - [ ] and - [x]
            if line.hasPrefix("- [ ] ") {
                let checkboxRange = NSRange(location: range.location, length: 5)
                checkboxRanges.append((nsRange: checkboxRange, isChecked: false))
                let checkboxAttrs: [NSAttributedString.Key: Any] = [
                    .foregroundColor: NSColor(white: 0.5, alpha: 1.0),
                    .link: "hashy-todo://\(range.location)",
                ]
                applyAttributes(checkboxAttrs, nsRange: checkboxRange, in: textView)
                let textRange = NSRange(location: range.location + 6, length: max(0, range.length - 6))
                if textRange.length > 0 {
                    applyAttributes([
                        .foregroundColor: NSColor.white.withAlphaComponent(0.85),
                    ], nsRange: textRange, in: textView)
                }
                return
            }

            if line.hasPrefix("- [x] ") || line.hasPrefix("- [X] ") {
                let checkboxRange = NSRange(location: range.location, length: 5)
                checkboxRanges.append((nsRange: checkboxRange, isChecked: true))
                let checkboxAttrs: [NSAttributedString.Key: Any] = [
                    .foregroundColor: NSColor(red: 0.32, green: 0.90, blue: 0.55, alpha: 1.0),
                    .link: "hashy-todo://\(range.location)",
                ]
                applyAttributes(checkboxAttrs, nsRange: checkboxRange, in: textView)
                let textRange = NSRange(location: range.location + 6, length: max(0, range.length - 6))
                if textRange.length > 0 {
                    applyAttributes([
                        .foregroundColor: NSColor.white.withAlphaComponent(0.4),
                        .strikethroughStyle: NSUnderlineStyle.single.rawValue,
                        .strikethroughColor: NSColor.white.withAlphaComponent(0.25),
                    ], nsRange: textRange, in: textView)
                }
                return
            }

            // List items - / *
            if line.hasPrefix("- ") || line.hasPrefix("* ") {
                let bulletRange = NSRange(location: range.location, length: 2)
                applyAttributes([
                    .foregroundColor: NSColor(red: 0.32, green: 0.90, blue: 0.55, alpha: 1.0),
                ], nsRange: bulletRange, in: textView)
            }

            // Markdown links [text](url) — but not image links ![text](url)
            applyMarkdownLinks(in: line, lineRange: range, textView: textView)

            // Bare URLs (https://... or http://...)
            applyBareURLLinks(in: line, lineRange: range, textView: textView)
        }

        private func applyMarkdownLinks(in line: String, lineRange: NSRange, textView: STTextView) {
            // Match [text](url) but not preceded by !
            let pattern = #"(?<!!)\[([^\]]+)\]\(([^)]+)\)"#
            guard let regex = try? NSRegularExpression(pattern: pattern) else { return }
            let nsLine = line as NSString
            let matches = regex.matches(in: line, range: NSRange(location: 0, length: nsLine.length))

            let hiddenFont = NSFont.monospacedSystemFont(ofSize: 0.01, weight: .regular)
            let hiddenAttrs: [NSAttributedString.Key: Any] = [
                .foregroundColor: NSColor.clear,
                .font: hiddenFont,
            ]

            for match in matches {
                let textRange = match.range(at: 1)
                let urlRange = match.range(at: 2)
                let urlString = nsLine.substring(with: urlRange)

                // Hide opening [
                let openBracket = NSRange(location: lineRange.location + match.range.location, length: 1)
                applyAttributes(hiddenAttrs, nsRange: openBracket, in: textView)

                // Style the link text
                let absoluteTextRange = NSRange(location: lineRange.location + textRange.location, length: textRange.length)
                let linkAttrs: [NSAttributedString.Key: Any] = [
                    .foregroundColor: NSColor(red: 0.45, green: 0.75, blue: 1.0, alpha: 1.0),
                    .underlineStyle: NSUnderlineStyle.single.rawValue,
                    .underlineColor: NSColor(red: 0.45, green: 0.75, blue: 1.0, alpha: 0.4),
                    .link: "hashy-url://\(urlString)",
                    .toolTip: urlString,
                ]
                applyAttributes(linkAttrs, nsRange: absoluteTextRange, in: textView)

                // Hide ](url)
                let suffixStart = lineRange.location + textRange.location + textRange.length
                let suffixLength = match.range.length - textRange.length - 1 // -1 for the opening [
                let suffixRange = NSRange(location: suffixStart, length: suffixLength)
                applyAttributes(hiddenAttrs, nsRange: suffixRange, in: textView)
            }
        }

        private func applyBareURLLinks(in line: String, lineRange: NSRange, textView: STTextView) {
            let pattern = #"(?<!\(|"|')https?://[^\s\)\]>\"']+"#
            guard let regex = try? NSRegularExpression(pattern: pattern) else { return }
            let nsLine = line as NSString
            let matches = regex.matches(in: line, range: NSRange(location: 0, length: nsLine.length))

            for match in matches {
                let urlString = nsLine.substring(with: match.range)
                let absoluteRange = NSRange(location: lineRange.location + match.range.location, length: match.range.length)
                let linkAttrs: [NSAttributedString.Key: Any] = [
                    .foregroundColor: NSColor(red: 0.45, green: 0.75, blue: 1.0, alpha: 1.0),
                    .underlineStyle: NSUnderlineStyle.single.rawValue,
                    .underlineColor: NSColor(red: 0.45, green: 0.75, blue: 1.0, alpha: 0.4),
                    .link: "hashy-url://\(urlString)",
                    .toolTip: urlString,
                ]
                applyAttributes(linkAttrs, nsRange: absoluteRange, in: textView)
            }
        }

        private func countLeadingHashes(_ line: String) -> Int {
            var count = 0
            for ch in line {
                if ch == "#" { count += 1 }
                else if ch == " " && count > 0 { return count }
                else { return 0 }
            }
            return 0
        }

        private func applyInlinePattern(_ pattern: String, in line: String, lineRange: NSRange, textView: STTextView, attrs: [NSAttributedString.Key: Any]) {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { return }
            let nsLine = line as NSString
            let matches = regex.matches(in: line, range: NSRange(location: 0, length: nsLine.length))
            for match in matches {
                let absoluteRange = NSRange(location: lineRange.location + match.range.location, length: match.range.length)
                applyAttributes(attrs, nsRange: absoluteRange, in: textView)
            }
        }

        private func applyAttributes(_ attrs: [NSAttributedString.Key: Any], nsRange: NSRange, in textView: STTextView) {
            textView.addAttributes(attrs, range: nsRange)
        }
    }
}

#elseif canImport(UIKit)
import UIKit

// MARK: - iOS Hashy Editor View

/// A native TextKit 2 markdown editor for iOS using STTextView.
/// Feature-parity with the macOS editor: syntax highlighting, tappable
/// links/checkboxes, inline images, overlay buttons, and a keyboard toolbar.
public struct HashyEditorView: UIViewRepresentable {
    @Binding public var text: String
    public var font: UIFont
    public var textColor: UIColor
    public var backgroundColor: UIColor
    public var isEditable: Bool
    public var showLineNumbers: Bool
    public var showOverlayButtons: Bool
    public var wikiLinkResolver: WikiLinkResolver?
    public var completionProvider: ((String) -> [HashyCompletionResult])?
    public var onEmbedTrigger: ((WikiLinkInsertion.Trigger) -> Void)?
    public var onLinkClicked: ((String) -> Void)?
    public var onTextChange: ((String) -> Void)?
    public var onOverlayButtonTapped: ((OverlayItem) -> Void)?
    public var imageBaseURL: URL?
    public var focusTrigger: Int = 0

    public init(
        text: Binding<String>,
        font: Any? = nil,
        textColor: Any? = nil,
        backgroundColor: Any? = nil,
        isEditable: Bool = true,
        showLineNumbers: Bool = false,
        showOverlayButtons: Bool = false,
        wikiLinkResolver: WikiLinkResolver? = nil,
        completionProvider: ((String) -> [HashyCompletionResult])? = nil,
        onEmbedTrigger: ((WikiLinkInsertion.Trigger) -> Void)? = nil,
        onLinkClicked: ((String) -> Void)? = nil,
        onTextChange: ((String) -> Void)? = nil,
        onOverlayButtonTapped: ((OverlayItem) -> Void)? = nil,
        imageBaseURL: URL? = nil,
        focusTrigger: Int = 0
    ) {
        self._text = text
        self.font = (font as? UIFont) ?? .monospacedSystemFont(ofSize: 14, weight: .regular)
        self.textColor = (textColor as? UIColor) ?? .white.withAlphaComponent(0.92)
        self.backgroundColor = (backgroundColor as? UIColor) ?? .black
        self.isEditable = isEditable
        self.showLineNumbers = showLineNumbers
        self.showOverlayButtons = showOverlayButtons
        self.wikiLinkResolver = wikiLinkResolver
        self.completionProvider = completionProvider
        self.onEmbedTrigger = onEmbedTrigger
        self.onLinkClicked = onLinkClicked
        self.onTextChange = onTextChange
        self.onOverlayButtonTapped = onOverlayButtonTapped
        self.imageBaseURL = imageBaseURL
        self.focusTrigger = focusTrigger
    }

    public func makeUIView(context: Context) -> HashyTextView {
        let textView = HashyTextView()
        configureTextView(textView)

        let coordinator = context.coordinator
        textView.textDelegate = coordinator
        coordinator.textView = textView
        coordinator.parent = self

        // Add overlay plugin if enabled
        if showOverlayButtons {
            let overlayPlugin = HashyOverlayPlugin(delegate: coordinator)
            coordinator.overlayPlugin = overlayPlugin
            textView.addPlugin(overlayPlugin)
        }

        // Wire image save handler for paste
        textView.imageSaveHandler = { [weak coordinator] data, _, filename in
            coordinator?.saveDroppedImage(data: data, filename: filename)
        }

        // Wire hardware keyboard shortcuts
        textView.keyCommandHandler = { [weak coordinator] command in
            guard let coordinator = coordinator else { return }
            switch (command.modifierFlags, command.input) {
            case (.command, "b"): coordinator.handleBold()
            case (.command, "i"): coordinator.handleItalic()
            case (.command, "\r"): coordinator.handleCmdReturn()
            default: break
            }
        }

        // Set initial content with proper base attributes
        coordinator.setTextWithBaseAttributes(text)

        // Keyboard accessory toolbar
        coordinator.installInputAccessory(on: textView)

        // Replace the default iOS shortcut strip with Hashy's markdown actions
        textView.inputAssistantItem.leadingBarButtonGroups = []
        textView.inputAssistantItem.trailingBarButtonGroups = []

        // Tap gesture for links and checkboxes
        let tapGesture = UITapGestureRecognizer(target: coordinator, action: #selector(Coordinator.handleTap(_:)))
        tapGesture.delegate = coordinator
        textView.addGestureRecognizer(tapGesture)

        return textView
    }

    public func updateUIView(_ textView: HashyTextView, context: Context) {
        context.coordinator.parent = self

        if !context.coordinator.isInternalUpdate && textView.text != text {
            let cursorBefore = textView.offset(from: textView.beginningOfDocument, to: textView.selectedTextRange?.start ?? textView.beginningOfDocument)
            print("[Hashy] updateUIView: RESETTING text (cursor was \(cursorBefore), tvLen=\(textView.text?.count ?? -1), bindLen=\(text.count))")
            context.coordinator.isInternalUpdate = true
            context.coordinator.setTextWithBaseAttributes(text)
            context.coordinator.isInternalUpdate = false
        }

        textView.isEditable = isEditable

        if context.coordinator.lastFocusTrigger != focusTrigger {
            context.coordinator.lastFocusTrigger = focusTrigger
            DispatchQueue.main.async {
                textView.becomeFirstResponder()
            }
        }
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    private func configureTextView(_ textView: HashyTextView) {
        textView.font = font
        textView.textColor = textColor
        textView.backgroundColor = backgroundColor
        textView.isEditable = isEditable
        textView.showsLineNumbers = showLineNumbers
        textView.highlightSelectedLine = true
        textView.isHorizontallyResizable = false
        textView.alwaysBounceVertical = true
        textView.keyboardDismissMode = .none
        textView.autocapitalizationType = .none
        textView.autocorrectionType = .no
        textView.smartDashesType = .no
        textView.smartQuotesType = .no

        let paragraph = NSMutableParagraphStyle()
        paragraph.lineHeightMultiple = 1.4
        paragraph.defaultTabInterval = 28
        textView.defaultParagraphStyle = paragraph
    }

    // MARK: - Keyboard Accessory

    private final class KeyboardAccessoryContainerView: UIView {
        override var intrinsicContentSize: CGSize {
            CGSize(width: UIView.noIntrinsicMetric, height: 42)
        }
    }

    // MARK: - Image Preview

    private class ImagePreviewController: UIViewController {
        private let previewImage: UIImage

        init(image: UIImage) {
            self.previewImage = image
            super.init(nibName: nil, bundle: nil)
            modalPresentationStyle = .fullScreen
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) { fatalError() }

        override func viewDidLoad() {
            super.viewDidLoad()
            view.backgroundColor = .black

            let iv = UIImageView(image: previewImage)
            iv.contentMode = .scaleAspectFit
            iv.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(iv)

            NSLayoutConstraint.activate([
                iv.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                iv.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                iv.topAnchor.constraint(equalTo: view.topAnchor),
                iv.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            ])

            let tap = UITapGestureRecognizer(target: self, action: #selector(dismissPreview))
            view.addGestureRecognizer(tap)
        }

        @objc private func dismissPreview() {
            dismiss(animated: true)
        }
    }

    // MARK: - Coordinator

    public class Coordinator: NSObject, STTextViewDelegate, OverlayButtonDelegate, UIGestureRecognizerDelegate {
        var parent: HashyEditorView
        weak var textView: HashyTextView?
        var isInternalUpdate = false
        var overlayPlugin: HashyOverlayPlugin?
        var lastFocusTrigger: Int = 0

        /// Tracks checkbox ranges for click detection
        private var checkboxRanges: [(nsRange: NSRange, isChecked: Bool)] = []

        /// Image overlay views keyed by character offset of `!`
        private var imageViews: [Int: UIImageView] = [:]
        /// Resolved URLs keyed by character offset (for preview)
        private var imageURLs: [Int: URL] = [:]
        /// Loaded image cache keyed by resolved URL string
        private var imageCache: [String: UIImage] = [:]
        /// URLs currently being fetched (prevents duplicate downloads)
        private var imageFetchesInFlight: Set<String> = []

        init(_ parent: HashyEditorView) {
            self.parent = parent
        }

        deinit {
            for (_, view) in imageViews {
                view.removeFromSuperview()
            }
        }

        // MARK: - OverlayButtonDelegate

        public func overlayButtonTapped(item: OverlayItem) {
            parent.onOverlayButtonTapped?(item)
        }

        // MARK: - Image Drop/Paste

        func saveDroppedImage(data: Data, filename: String) -> String? {
            guard let baseURL = parent.imageBaseURL else { return nil }
            let assetsURL = baseURL.appendingPathComponent("_assets")
            do {
                try FileManager.default.createDirectory(at: assetsURL, withIntermediateDirectories: true)
                let fileURL = assetsURL.appendingPathComponent(filename)
                try data.write(to: fileURL, options: .atomic)
                return "_assets/\(filename)"
            } catch {
                return nil
            }
        }

        // MARK: - UIGestureRecognizerDelegate

        public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            true
        }

        // MARK: - Tap Handling (links + checkboxes)

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard gesture.state == .ended else { return }
            guard let textView = textView else { return }

            let point = gesture.location(in: textView)

            // Use UITextInput API to find the character at the tap point
            guard let tapPosition = textView.closestPosition(to: point) else { return }
            let offset = textView.offset(from: textView.beginningOfDocument, to: tapPosition)

            guard let contentStorage = textView.textContentManager as? NSTextContentStorage,
                  let textStorage = contentStorage.textStorage else { return }
            guard offset >= 0 && offset < textStorage.length else { return }

            let attrs = textStorage.attributes(at: offset, effectiveRange: nil)
            if let link = attrs[.link] {
                let linkString: String
                if let url = link as? URL {
                    linkString = url.absoluteString
                } else if let str = link as? String {
                    linkString = str
                } else {
                    return
                }
                let docStart = textView.textContentManager.documentRange.location
                if let location = textView.textContentManager.location(docStart, offsetBy: offset) {
                    _ = self.textView(textView, clickedOnLink: linkString, at: location)
                }
            }
        }

        // MARK: - Text Change Handling

        public func textViewDidChangeText(_ notification: Notification) {
            guard !isInternalUpdate else { return }
            guard let textView = textView else { return }

            let cursorBefore = textView.offset(from: textView.beginningOfDocument, to: textView.selectedTextRange?.start ?? textView.beginningOfDocument)
            print("[Hashy] textViewDidChangeText: cursor before highlighting=\(cursorBefore)")

            isInternalUpdate = true

            let newText = textView.text ?? ""
            parent.text = newText
            parent.onTextChange?(newText)

            // Re-apply highlighting after change
            applyHighlighting()

            isInternalUpdate = false

            let cursorAfter = textView.offset(from: textView.beginningOfDocument, to: textView.selectedTextRange?.start ?? textView.beginningOfDocument)
            print("[Hashy] textViewDidChangeText: cursor after highlighting=\(cursorAfter)")
        }

        /// Detects @ and [[ triggers and handles list continuation
        public func textView(_ textView: STTextView, didChangeTextIn affectedCharRange: NSTextRange, replacementString: String) {
            guard !isInternalUpdate else { return }

            let text = textView.text ?? ""
            let docStart = textView.textContentManager.documentRange.location
            let endOffset = textView.textContentManager.offset(from: docStart, to: affectedCharRange.endLocation)

            // Detect @ trigger (after whitespace or at line start)
            if replacementString == "@" {
                let startOffset = textView.textContentManager.offset(from: docStart, to: affectedCharRange.location)
                if startOffset == 0 || charBefore(offset: startOffset, in: text)?.isWhitespace == true || charBefore(offset: startOffset, in: text)?.isNewline == true {
                    parent.onEmbedTrigger?(.mention)
                }
            }

            // Detect [[ trigger
            let insertEnd = endOffset + replacementString.count
            if replacementString == "[" && insertEnd >= 2 {
                let startIdx = text.index(text.startIndex, offsetBy: insertEnd - 2, limitedBy: text.endIndex)
                let endIdx = text.index(text.startIndex, offsetBy: insertEnd, limitedBy: text.endIndex)
                if let startIdx, let endIdx, String(text[startIdx..<endIdx]) == "[[" {
                    parent.onEmbedTrigger?(.wikiLink)
                }
            }

            // List continuation: when Enter is pressed, continue list prefix
            if replacementString == "\n" {
                handleListContinuation(textView: textView, text: text, insertOffset: insertEnd)
            }
        }

        // MARK: - Link Click Handling (Checkboxes + Wiki-Links)

        public func textView(_ textView: STTextView, clickedOnLink link: Any, at location: any NSTextLocation) -> Bool {
            guard let linkString = link as? String else { return false }

            if linkString.hasPrefix("hashy-todo://") {
                let offsetStr = linkString.replacingOccurrences(of: "hashy-todo://", with: "")
                if let offset = Int(offsetStr) {
                    toggleCheckbox(at: offset)
                }
                return true
            }

            if linkString.hasPrefix("hashy-link://") {
                let objectId = linkString.replacingOccurrences(of: "hashy-link://", with: "")
                parent.onLinkClicked?(objectId)
                return true
            }

            if linkString.hasPrefix("hashy-url://") {
                let urlString = linkString.replacingOccurrences(of: "hashy-url://", with: "")
                if let url = URL(string: urlString) {
                    UIApplication.shared.open(url)
                }
                return true
            }

            return false
        }

        private func toggleCheckbox(at offset: Int) {
            guard let textView = textView, var text = textView.text else { return }
            guard offset + 5 <= text.count else { return }

            let checkStart = text.index(text.startIndex, offsetBy: offset)
            let checkEnd = text.index(checkStart, offsetBy: 5)
            let current = String(text[checkStart..<checkEnd])

            let replacement: String
            if current == "- [ ]" {
                replacement = "- [x]"
            } else if current == "- [x]" || current == "- [X]" {
                replacement = "- [ ]"
            } else {
                return
            }

            text.replaceSubrange(checkStart..<checkEnd, with: replacement)

            isInternalUpdate = true
            textView.text = text
            parent.text = text
            parent.onTextChange?(text)
            applyHighlighting()
            isInternalUpdate = false
        }

        // MARK: - Cmd+Return Todo Toggle

        func handleCmdReturn() {
            guard let textView = textView, var text = textView.text else { return }

            let docStart = textView.textContentManager.documentRange.location
            guard let sel = textView.textLayoutManager.textSelections.first,
                  let selRange = sel.textRanges.first else { return }
            let cursorOffset = textView.textContentManager.offset(from: docStart, to: selRange.location)

            let nsText = text as NSString
            let lineRange = nsText.lineRange(for: NSRange(location: cursorOffset, length: 0))
            let line = nsText.substring(with: lineRange)

            let newLine: String
            if line.hasPrefix("- [ ] ") {
                newLine = "- [x] " + String(line.dropFirst(6))
            } else if line.hasPrefix("- [x] ") || line.hasPrefix("- [X] ") {
                newLine = "- [ ] " + String(line.dropFirst(6))
            } else if line.hasPrefix("- ") {
                newLine = "- [ ] " + String(line.dropFirst(2))
            } else {
                newLine = "- [ ] " + line
            }

            let replaceStart = text.index(text.startIndex, offsetBy: lineRange.location)
            let replaceEnd = text.index(replaceStart, offsetBy: lineRange.length)
            text.replaceSubrange(replaceStart..<replaceEnd, with: newLine)

            let lengthDelta = newLine.count - line.count
            let newCursorOffset = cursorOffset + lengthDelta

            isInternalUpdate = true
            textView.text = text
            parent.text = text
            parent.onTextChange?(text)
            applyHighlighting()
            isInternalUpdate = false

            setCursorPosition(in: textView, offset: max(lineRange.location, newCursorOffset))
        }

        // MARK: - List Continuation

        private func handleListContinuation(textView: STTextView, text: String, insertOffset: Int) {
            let cursorIdx = text.index(text.startIndex, offsetBy: min(insertOffset, text.count))
            let textBeforeCursor = String(text[..<cursorIdx])

            let lines = textBeforeCursor.components(separatedBy: "\n")
            guard lines.count >= 2 else { return }
            let previousLine = lines[lines.count - 2]

            // Detect list prefix
            let prefix: String?
            if previousLine.hasPrefix("- [x] ") || previousLine.hasPrefix("- [X] ") {
                prefix = "- [ ] "
            } else if previousLine.hasPrefix("- [ ] ") {
                prefix = "- [ ] "
            } else if previousLine.hasPrefix("- ") {
                prefix = "- "
            } else if previousLine.hasPrefix("* ") {
                prefix = "* "
            } else {
                prefix = nil
            }

            guard let listPrefix = prefix else { return }

            let contentAfterPrefix: String
            if previousLine.hasPrefix("- [x] ") || previousLine.hasPrefix("- [X] ") || previousLine.hasPrefix("- [ ] ") {
                contentAfterPrefix = String(previousLine.dropFirst(6))
            } else {
                contentAfterPrefix = String(previousLine.dropFirst(2))
            }

            if contentAfterPrefix.trimmingCharacters(in: .whitespaces).isEmpty {
                let prefixStart = insertOffset - 1 - previousLine.count
                guard prefixStart >= 0 else { return }
                let removeStart = text.index(text.startIndex, offsetBy: prefixStart)
                let removeEnd = text.index(text.startIndex, offsetBy: min(insertOffset, text.count))
                var newText = text
                newText.replaceSubrange(removeStart..<removeEnd, with: "\n")

                isInternalUpdate = true
                textView.text = newText
                parent.text = newText
                parent.onTextChange?(newText)
                applyHighlighting()
                isInternalUpdate = false

                let newCursorOffset = prefixStart + 1
                setCursorPosition(in: textView, offset: newCursorOffset)
            } else {
                var newText = text
                let insertIdx = text.index(text.startIndex, offsetBy: min(insertOffset, text.count))
                newText.insert(contentsOf: listPrefix, at: insertIdx)

                isInternalUpdate = true
                textView.text = newText
                parent.text = newText
                parent.onTextChange?(newText)
                applyHighlighting()
                isInternalUpdate = false

                let newCursorOffset = insertOffset + listPrefix.count
                setCursorPosition(in: textView, offset: newCursorOffset)
            }
        }

        private func setCursorPosition(in textView: STTextView, offset: Int) {
            // Use UITextInput API — more reliable than setting textLayoutManager.textSelections directly
            guard let pos = textView.position(from: textView.beginningOfDocument, offset: offset) else {
                print("[Hashy] setCursorPosition: could not create position for offset \(offset)")
                return
            }
            textView.selectedTextRange = textView.textRange(from: pos, to: pos)
            print("[Hashy] setCursorPosition: set to offset \(offset)")
        }

        private func charBefore(offset: Int, in text: String) -> Character? {
            guard offset > 0 else { return nil }
            let idx = text.index(text.startIndex, offsetBy: offset - 1, limitedBy: text.endIndex)
            guard let idx else { return nil }
            return text[idx]
        }

        // MARK: - Editor Helpers

        private struct SelectionInfo {
            let start: Int
            let end: Int
            var hasSelection: Bool { start != end }
        }

        private func getSelection(in textView: STTextView) -> SelectionInfo? {
            let docStart = textView.textContentManager.documentRange.location
            guard let sel = textView.textLayoutManager.textSelections.first,
                  let selRange = sel.textRanges.first else { return nil }
            let start = textView.textContentManager.offset(from: docStart, to: selRange.location)
            let end = textView.textContentManager.offset(from: docStart, to: selRange.endLocation)
            return SelectionInfo(start: start, end: end)
        }

        private func setSelectionRange(in textView: STTextView, start: Int, end: Int) {
            let docStart = textView.textContentManager.documentRange.location
            guard let startLoc = textView.textContentManager.location(docStart, offsetBy: start),
                  let endLoc = textView.textContentManager.location(docStart, offsetBy: end),
                  let range = NSTextRange(location: startLoc, end: endLoc) else { return }
            textView.textLayoutManager.textSelections = [
                NSTextSelection(range: range, affinity: .downstream, granularity: .character)
            ]
            textView.setNeedsLayout()
        }

        private func commitText(_ text: String) {
            guard let textView = textView else { return }
            isInternalUpdate = true
            parent.text = text
            parent.onTextChange?(text)
            setTextWithBaseAttributes(text)
            isInternalUpdate = false
        }

        private func lineRanges(in text: String, from start: Int, to end: Int) -> [NSRange] {
            let nsText = text as NSString
            var ranges: [NSRange] = []
            var pos = start
            while pos <= end && pos < nsText.length {
                let lineRange = nsText.lineRange(for: NSRange(location: pos, length: 0))
                ranges.append(lineRange)
                let next = lineRange.location + lineRange.length
                if next <= pos { break }
                pos = next
            }
            return ranges
        }

        // MARK: - Formatting Shortcuts

        func handleBold() {
            wrapSelection(prefix: "**", suffix: "**")
        }

        func handleItalic() {
            wrapSelection(prefix: "*", suffix: "*")
        }

        private func wrapSelection(prefix: String, suffix: String) {
            guard let textView = textView, let text = textView.text else { return }
            guard let sel = getSelection(in: textView) else { return }
            var newText = text
            if sel.hasSelection {
                let startIdx = text.index(text.startIndex, offsetBy: sel.start)
                let endIdx = text.index(text.startIndex, offsetBy: sel.end)
                let selected = String(text[startIdx..<endIdx])
                newText.replaceSubrange(startIdx..<endIdx, with: "\(prefix)\(selected)\(suffix)")
                commitText(newText)
                setSelectionRange(in: textView, start: sel.start + prefix.count, end: sel.start + prefix.count + selected.count)
            } else {
                let insertIdx = text.index(text.startIndex, offsetBy: sel.start)
                newText.insert(contentsOf: "\(prefix)\(suffix)", at: insertIdx)
                commitText(newText)
                setCursorPosition(in: textView, offset: sel.start + prefix.count)
            }
        }

        // MARK: - Indent/Outdent

        func handleIndent() {
            guard let textView = textView, let text = textView.text else { return }
            guard let sel = getSelection(in: textView) else { return }
            let effectiveEnd = sel.hasSelection ? max(sel.start, sel.end - 1) : sel.start
            let lines = lineRanges(in: text, from: sel.start, to: effectiveEnd)
            guard !lines.isEmpty else { return }
            var newText = text
            var insertedTotal = 0
            for lineRange in lines {
                let insertIdx = newText.index(newText.startIndex, offsetBy: lineRange.location + insertedTotal)
                newText.insert(contentsOf: "  ", at: insertIdx)
                insertedTotal += 2
            }
            commitText(newText)
            if sel.hasSelection {
                setSelectionRange(in: textView, start: sel.start + 2, end: sel.end + insertedTotal)
            } else {
                setCursorPosition(in: textView, offset: sel.start + 2)
            }
        }

        func handleOutdent() {
            guard let textView = textView, let text = textView.text else { return }
            guard let sel = getSelection(in: textView) else { return }
            let effectiveEnd = sel.hasSelection ? max(sel.start, sel.end - 1) : sel.start
            let lines = lineRanges(in: text, from: sel.start, to: effectiveEnd)
            guard !lines.isEmpty else { return }
            var newText = text
            var removedTotal = 0
            var firstLineRemoved = 0
            for (i, lineRange) in lines.enumerated() {
                let loc = lineRange.location - removedTotal
                let lineStartIdx = newText.index(newText.startIndex, offsetBy: loc)
                var spacesToRemove = 0
                var checkIdx = lineStartIdx
                while spacesToRemove < 2 && checkIdx < newText.endIndex && newText[checkIdx] == " " {
                    spacesToRemove += 1
                    checkIdx = newText.index(after: checkIdx)
                }
                if spacesToRemove > 0 {
                    newText.removeSubrange(lineStartIdx..<newText.index(lineStartIdx, offsetBy: spacesToRemove))
                    removedTotal += spacesToRemove
                    if i == 0 { firstLineRemoved = spacesToRemove }
                }
            }
            guard removedTotal > 0 else { return }
            commitText(newText)
            if sel.hasSelection {
                setSelectionRange(in: textView, start: max(0, sel.start - firstLineRemoved), end: max(0, sel.end - removedTotal))
            } else {
                setCursorPosition(in: textView, offset: max(0, sel.start - firstLineRemoved))
            }
        }

        // MARK: - Text Setting

        /// Sets text on the text view as an NSAttributedString with proper base
        /// foreground color and font, avoiding the TextKit 2 race condition
        /// where setting plain text can leave characters with system default color.
        func setTextWithBaseAttributes(_ text: String) {
            guard let textView = textView else { return }

            let paragraph = NSMutableParagraphStyle()
            paragraph.lineHeightMultiple = 1.4
            paragraph.defaultTabInterval = 28

            let baseAttrs: [NSAttributedString.Key: Any] = [
                .foregroundColor: parent.textColor,
                .font: parent.font,
                .paragraphStyle: paragraph,
            ]

            let attrString = NSAttributedString(string: text, attributes: baseAttrs)

            if let contentStorage = textView.textContentManager as? NSTextContentStorage,
               let textStorage = contentStorage.textStorage {
                textStorage.setAttributedString(attrString)
            } else {
                textView.text = text
            }

            applyHighlighting()

            textView.textLayoutManager.ensureLayout(for: textView.textContentManager.documentRange)
            DispatchQueue.main.async { [weak textView] in
                guard let textView else { return }
                textView.textLayoutManager.textViewportLayoutController.layoutViewport()
                textView.setNeedsDisplay()
            }
        }

        // MARK: - Keyboard Accessory Toolbar

        func installInputAccessory(on textView: HashyTextView) {
            let container = KeyboardAccessoryContainerView(
                frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 42)
            )
            container.backgroundColor = UIColor(white: 0.06, alpha: 0.95)

            let scrollView = UIScrollView()
            scrollView.showsHorizontalScrollIndicator = false
            scrollView.alwaysBounceHorizontal = true
            scrollView.keyboardDismissMode = .none
            scrollView.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(scrollView)

            NSLayoutConstraint.activate([
                scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 4),
                scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -4),
                scrollView.topAnchor.constraint(equalTo: container.topAnchor, constant: 4),
                scrollView.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -4),
            ])

            let stack = UIStackView()
            stack.axis = .horizontal
            stack.alignment = .center
            stack.spacing = 4
            stack.translatesAutoresizingMaskIntoConstraints = false
            scrollView.addSubview(stack)

            NSLayoutConstraint.activate([
                stack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
                stack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
                stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
                stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
                stack.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor),
            ])

            let buttons: [(String, Selector)] = [
                ("☐", #selector(insertTodo)),
                ("H1", #selector(insertHeading)),
                ("H2", #selector(insertHeading2)),
                ("•", #selector(insertBullet)),
                ("1.", #selector(insertNumbered)),
                ("❝", #selector(insertQuote)),
                ("```", #selector(insertCodeBlock)),
                ("B", #selector(insertBold)),
                ("`", #selector(insertCode)),
                ("[[]]", #selector(insertWikiLink)),
                ("#", #selector(insertTag)),
                ("🔗", #selector(insertLink)),
            ]

            for (title, action) in buttons {
                let button = UIButton(type: .system)
                button.setTitle(title, for: .normal)
                button.titleLabel?.font = .systemFont(ofSize: 12, weight: .medium)
                button.setTitleColor(UIColor(red: 0.32, green: 0.90, blue: 0.55, alpha: 1.0), for: .normal)
                button.backgroundColor = UIColor(white: 0.12, alpha: 1.0)
                button.layer.cornerRadius = 6
                button.contentEdgeInsets = UIEdgeInsets(top: 4, left: 7, bottom: 4, right: 7)
                button.addTarget(self, action: action, for: .touchUpInside)
                button.heightAnchor.constraint(equalToConstant: 28).isActive = true
                button.setContentCompressionResistancePriority(.required, for: .horizontal)
                stack.addArrangedSubview(button)
            }

            textView.customInputAccessoryView = container
            textView.reloadInputViews()
        }

        @objc private func insertTodo() { insertSnippet("- [ ] ") }
        @objc private func insertHeading() { insertSnippet("# ") }
        @objc private func insertHeading2() { insertSnippet("## ") }
        @objc private func insertBullet() { insertSnippet("- ") }
        @objc private func insertNumbered() { insertSnippet("1. ") }
        @objc private func insertQuote() { insertSnippet("> ") }
        @objc private func insertCodeBlock() { insertSnippet("```\n\n```", cursorBacktrack: 4) }
        @objc private func insertBold() { insertSnippet("****", cursorBacktrack: 2) }
        @objc private func insertCode() { insertSnippet("``", cursorBacktrack: 1) }
        @objc private func insertWikiLink() { insertSnippet("[[]]", cursorBacktrack: 2) }
        @objc private func insertTag() { insertSnippet("#") }
        @objc private func insertLink() { insertSnippet("[title](https://)", cursorBacktrack: 10) }

        private func insertSnippet(_ snippet: String, cursorBacktrack: Int = 0) {
            #if os(iOS)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            #endif
            guard let textView = textView else { return }

            // Log cursor before
            let beforeOffset = textView.offset(from: textView.beginningOfDocument, to: textView.selectedTextRange?.start ?? textView.beginningOfDocument)
            print("[Hashy] insertSnippet: '\(snippet)' cursorBefore=\(beforeOffset)")

            // Use insertText so STTextView handles cursor positioning natively.
            textView.insertText(snippet, replacementRange: NSRange(location: NSNotFound, length: 0))

            // Log cursor after insertText (before highlighting)
            let afterInsert = textView.offset(from: textView.beginningOfDocument, to: textView.selectedTextRange?.start ?? textView.beginningOfDocument)
            print("[Hashy] insertSnippet: afterInsertText cursor=\(afterInsert)")

            // For snippets like **** where the cursor should sit between the
            // delimiters, move it back after the insertion.
            if cursorBacktrack > 0 {
                let target = max(0, afterInsert - cursorBacktrack)
                print("[Hashy] insertSnippet: backtracking to \(target)")
                setCursorPosition(in: textView, offset: target)
            }

            // Log final cursor
            let finalOffset = textView.offset(from: textView.beginningOfDocument, to: textView.selectedTextRange?.start ?? textView.beginningOfDocument)
            print("[Hashy] insertSnippet: final cursor=\(finalOffset)")
        }

        // MARK: - Image Rendering

        private func imageDisplaySize(for image: UIImage, in textView: STTextView) -> CGSize {
            let maxWidth = min(image.size.width, textView.bounds.width - 40)
            let maxHeight: CGFloat = 300
            let scale = min(maxWidth / max(image.size.width, 1), maxHeight / max(image.size.height, 1), 1.0)
            return CGSize(width: image.size.width * scale, height: image.size.height * scale)
        }

        private func resolveImageURL(_ pathString: String) -> URL? {
            if pathString.hasPrefix("https://") || pathString.hasPrefix("http://") {
                return URL(string: pathString)
            } else if pathString.hasPrefix("/") {
                return URL(fileURLWithPath: pathString)
            } else if pathString.hasPrefix("file://") {
                return URL(string: pathString)
            } else if let baseURL = parent.imageBaseURL {
                return baseURL.appendingPathComponent(pathString)
            }
            return nil
        }

        private func applyImageRendering(text: String, textView: STTextView) {
            let pattern = #"!\[([^\]]*)\]\(([^)]+)\)"#
            guard let regex = try? NSRegularExpression(pattern: pattern) else { return }

            let nsText = text as NSString
            let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))

            let dimAttrs: [NSAttributedString.Key: Any] = [
                .foregroundColor: UIColor.white.withAlphaComponent(0.3),
            ]

            var activeOffsets = Set<Int>()

            for match in matches {
                let fullRange = match.range
                let pathString = nsText.substring(with: match.range(at: 2))

                // Dim the full ![alt](path) syntax
                applyAttributes(dimAttrs, nsRange: fullRange, in: textView)

                guard let imageURL = resolveImageURL(pathString) else { continue }
                let cacheKey = imageURL.absoluteString
                let offset = fullRange.location

                // Determine which line this image syntax is on
                let lineRange = nsText.lineRange(for: NSRange(location: offset, length: 0))

                // Load image (from cache, disk, or network)
                if let cached = imageCache[cacheKey] {
                    activeOffsets.insert(offset)
                    let displaySize = imageDisplaySize(for: cached, in: textView)
                    applyParagraphSpacing(displaySize.height + 8, at: lineRange, in: textView)
                    positionImageView(image: cached, at: offset, url: imageURL, in: textView)
                    continue
                }

                if imageURL.isFileURL {
                    if let loaded = UIImage(contentsOfFile: imageURL.path) {
                        imageCache[cacheKey] = loaded
                        activeOffsets.insert(offset)
                        let displaySize = imageDisplaySize(for: loaded, in: textView)
                        applyParagraphSpacing(displaySize.height + 8, at: lineRange, in: textView)
                        positionImageView(image: loaded, at: offset, url: imageURL, in: textView)
                    }
                } else {
                    // Async fetch for HTTP(S) URLs
                    activeOffsets.insert(offset)
                    guard !imageFetchesInFlight.contains(cacheKey) else { continue }
                    imageFetchesInFlight.insert(cacheKey)
                    URLSession.shared.dataTask(with: imageURL) { [weak self] data, _, _ in
                        guard let data = data, let image = UIImage(data: data) else { return }
                        DispatchQueue.main.async {
                            guard let self = self, self.textView != nil else { return }
                            self.imageCache[cacheKey] = image
                            self.imageFetchesInFlight.remove(cacheKey)
                            self.applyHighlighting()
                        }
                    }.resume()
                }
            }

            // Remove stale image views
            for (offset, view) in imageViews where !activeOffsets.contains(offset) {
                view.removeFromSuperview()
                imageViews.removeValue(forKey: offset)
                imageURLs.removeValue(forKey: offset)
            }
        }

        private func applyParagraphSpacing(_ spacing: CGFloat, at lineRange: NSRange, in textView: STTextView) {
            let paragraph = NSMutableParagraphStyle()
            paragraph.lineHeightMultiple = 1.4
            paragraph.defaultTabInterval = 28
            paragraph.paragraphSpacing = spacing
            applyAttributes([.paragraphStyle: paragraph], nsRange: lineRange, in: textView)
        }

        private func positionImageView(image: UIImage, at offset: Int, url: URL, in textView: STTextView) {
            DispatchQueue.main.async { [weak self, weak textView] in
                guard let self = self, let textView = textView else { return }

                let textLayoutManager = textView.textLayoutManager
                let textContentManager = textView.textContentManager
                let docStart = textContentManager.documentRange.location

                guard let matchLocation = textContentManager.location(docStart, offsetBy: offset) else { return }

                var lineFrame: CGRect?
                textLayoutManager.enumerateTextLayoutFragments(
                    from: matchLocation,
                    options: [.ensuresLayout]
                ) { layoutFragment in
                    lineFrame = layoutFragment.layoutFragmentFrame
                    return false
                }

                guard let lineFrame = lineFrame else { return }

                let displaySize = self.imageDisplaySize(for: image, in: textView)

                // Position in the paragraph spacing gap (below text baseline, above next line)
                let imageFrame = CGRect(
                    x: lineFrame.minX,
                    y: lineFrame.maxY - displaySize.height - 4,
                    width: displaySize.width,
                    height: displaySize.height
                )

                self.imageURLs[offset] = url

                if let existingView = self.imageViews[offset] {
                    existingView.image = image
                    existingView.frame = imageFrame
                } else {
                    let imageView = UIImageView(frame: imageFrame)
                    imageView.image = image
                    imageView.contentMode = .scaleAspectFit
                    imageView.layer.cornerRadius = 4
                    imageView.clipsToBounds = true
                    imageView.isUserInteractionEnabled = true
                    let tap = UITapGestureRecognizer(target: self, action: #selector(self.imageViewTapped(_:)))
                    imageView.addGestureRecognizer(tap)
                    textView.addSubview(imageView)
                    self.imageViews[offset] = imageView
                }
            }
        }

        // MARK: - Image Preview

        @objc private func imageViewTapped(_ sender: UITapGestureRecognizer) {
            guard let tappedView = sender.view as? UIImageView,
                  let image = tappedView.image else { return }

            let previewVC = ImagePreviewController(image: image)

            if let windowScene = textView?.window?.windowScene,
               let rootVC = windowScene.windows.first?.rootViewController {
                var topVC = rootVC
                while let presented = topVC.presentedViewController {
                    topVC = presented
                }
                topVC.present(previewVC, animated: true)
            }
        }

        // MARK: - Highlighting

        func applyHighlighting() {
            guard let textView = textView else { return }
            guard let text = textView.text, !text.isEmpty else {
                // Clear all image views when text is empty
                for (_, view) in imageViews { view.removeFromSuperview() }
                imageViews.removeAll()
                return
            }

            // Save cursor — the full-range setAttributes below triggers a layout
            // invalidation that desyncs UITextInteraction's visual caret.
            let savedCursor = textView.selectedTextRange

            // Reset base attributes on full range to clear stale .link, .underlineStyle, etc.
            let fullRange = NSRange(location: 0, length: (text as NSString).length)
            let paragraph = NSMutableParagraphStyle()
            paragraph.lineHeightMultiple = 1.4
            paragraph.defaultTabInterval = 28
            let baseAttrs: [NSAttributedString.Key: Any] = [
                .foregroundColor: parent.textColor,
                .font: parent.font,
                .paragraphStyle: paragraph,
            ]
            if let contentStorage = textView.textContentManager as? NSTextContentStorage,
               let textStorage = contentStorage.textStorage {
                textStorage.setAttributes(baseAttrs, range: fullRange)
            }

            checkboxRanges = []
            applyWikiLinkStyling(text: text, textView: textView)
            applyMarkdownStyling(text: text, textView: textView)
            applyImageRendering(text: text, textView: textView)

            // Restore cursor so UITextInteraction redraws the caret correctly
            textView.selectedTextRange = savedCursor
        }

        private func applyWikiLinkStyling(text: String, textView: STTextView) {
            let pattern = #"\[\[([^\]|]+)(?:\|([^\]]+))?\]\]"#
            guard let regex = try? NSRegularExpression(pattern: pattern) else { return }

            let nsText = text as NSString
            let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))

            let hiddenFont = UIFont.monospacedSystemFont(ofSize: 0.01, weight: .regular)
            let hiddenAttrs: [NSAttributedString.Key: Any] = [
                .foregroundColor: UIColor.clear,
                .font: hiddenFont,
            ]

            for match in matches {
                let targetId = nsText.substring(with: match.range(at: 1))
                var displayText = targetId
                let hasDisplayName = match.range(at: 2).location != NSNotFound
                if hasDisplayName {
                    displayText = nsText.substring(with: match.range(at: 2))
                }
                if let resolver = parent.wikiLinkResolver {
                    let resolved = resolver.resolve(id: targetId)
                    if let title = resolved.title {
                        displayText = title
                    }
                }

                let fullRange = match.range

                // Opening [[ — hidden
                let openBrackets = NSRange(location: fullRange.location, length: 2)
                applyAttributes(hiddenAttrs, nsRange: openBrackets, in: textView)

                // Closing ]] — hidden
                let closeBrackets = NSRange(location: fullRange.location + fullRange.length - 2, length: 2)
                applyAttributes(hiddenAttrs, nsRange: closeBrackets, in: textView)

                if hasDisplayName {
                    let idAndPipeRange = NSRange(location: fullRange.location + 2, length: match.range(at: 1).length + 1)
                    applyAttributes(hiddenAttrs, nsRange: idAndPipeRange, in: textView)

                    let nameRange = match.range(at: 2)
                    let chipAttrs: [NSAttributedString.Key: Any] = [
                        .foregroundColor: UIColor(red: 0.45, green: 0.75, blue: 1.0, alpha: 1.0),
                        .backgroundColor: UIColor(red: 0.25, green: 0.4, blue: 0.6, alpha: 0.3),
                        .link: "hashy-link://\(targetId)",
                    ]
                    applyAttributes(chipAttrs, nsRange: nameRange, in: textView)
                } else {
                    let idRange = match.range(at: 1)
                    let chipAttrs: [NSAttributedString.Key: Any] = [
                        .foregroundColor: UIColor(red: 0.45, green: 0.75, blue: 1.0, alpha: 1.0),
                        .backgroundColor: UIColor(red: 0.25, green: 0.4, blue: 0.6, alpha: 0.3),
                        .link: "hashy-link://\(targetId)",
                    ]
                    applyAttributes(chipAttrs, nsRange: idRange, in: textView)
                }
            }
        }

        private func applyMarkdownStyling(text: String, textView: STTextView) {
            let nsText = text as NSString

            nsText.enumerateSubstrings(in: NSRange(location: 0, length: nsText.length), options: [.byLines, .substringNotRequired]) { _, range, _, _ in
                let line = nsText.substring(with: range)
                self.styleMarkdownLine(line, at: range, in: textView)
            }
        }

        private func styleMarkdownLine(_ line: String, at range: NSRange, in textView: STTextView) {
            // Headings
            let headingLevel = countLeadingHashes(line)
            if headingLevel > 0 && headingLevel <= 6 {
                let sizes: [CGFloat] = [20, 18, 16, 14.5, 13.5, 13]
                let weights: [UIFont.Weight] = [.bold, .bold, .semibold, .semibold, .medium, .medium]
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.monospacedSystemFont(ofSize: sizes[headingLevel - 1], weight: weights[headingLevel - 1]),
                    .foregroundColor: UIColor.white.withAlphaComponent(0.95),
                ]
                applyAttributes(attrs, nsRange: range, in: textView)
                return
            }

            // Inline code `text`
            applyInlinePattern(#"`([^`]+)`"#, in: line, lineRange: range, textView: textView, attrs: [
                .foregroundColor: UIColor(red: 0.95, green: 0.75, blue: 0.25, alpha: 1.0),
                .backgroundColor: UIColor(white: 0.12, alpha: 1.0),
            ])

            // Bold **text**
            applyInlinePattern(#"\*\*(.+?)\*\*"#, in: line, lineRange: range, textView: textView, attrs: [
                .font: UIFont.monospacedSystemFont(ofSize: 13, weight: .bold),
                .foregroundColor: UIColor.white,
            ])

            // Italic *text*
            let italicFont = UIFont.monospacedSystemFont(ofSize: 13, weight: .regular)
            let italicDescriptor = italicFont.fontDescriptor.withSymbolicTraits(.traitItalic)
            applyInlinePattern(#"(?<!\*)\*(?!\*)(.+?)(?<!\*)\*(?!\*)"#, in: line, lineRange: range, textView: textView, attrs: [
                .font: italicDescriptor.map { UIFont(descriptor: $0, size: 13) } ?? italicFont,
                .obliqueness: 0.25 as NSNumber,
                .foregroundColor: UIColor.white.withAlphaComponent(0.80),
            ])

            // Blockquote > text
            if line.hasPrefix(">") {
                applyAttributes([
                    .foregroundColor: UIColor.white.withAlphaComponent(0.6),
                ], nsRange: range, in: textView)
            }

            // Todo checkboxes - [ ] and - [x]
            if line.hasPrefix("- [ ] ") {
                let checkboxRange = NSRange(location: range.location, length: 5)
                checkboxRanges.append((nsRange: checkboxRange, isChecked: false))
                let checkboxAttrs: [NSAttributedString.Key: Any] = [
                    .foregroundColor: UIColor(white: 0.5, alpha: 1.0),
                    .link: "hashy-todo://\(range.location)",
                ]
                applyAttributes(checkboxAttrs, nsRange: checkboxRange, in: textView)
                let textRange = NSRange(location: range.location + 6, length: max(0, range.length - 6))
                if textRange.length > 0 {
                    applyAttributes([
                        .foregroundColor: UIColor.white.withAlphaComponent(0.85),
                    ], nsRange: textRange, in: textView)
                }
                return
            }

            if line.hasPrefix("- [x] ") || line.hasPrefix("- [X] ") {
                let checkboxRange = NSRange(location: range.location, length: 5)
                checkboxRanges.append((nsRange: checkboxRange, isChecked: true))
                let checkboxAttrs: [NSAttributedString.Key: Any] = [
                    .foregroundColor: UIColor(red: 0.32, green: 0.90, blue: 0.55, alpha: 1.0),
                    .link: "hashy-todo://\(range.location)",
                ]
                applyAttributes(checkboxAttrs, nsRange: checkboxRange, in: textView)
                let textRange = NSRange(location: range.location + 6, length: max(0, range.length - 6))
                if textRange.length > 0 {
                    applyAttributes([
                        .foregroundColor: UIColor.white.withAlphaComponent(0.4),
                        .strikethroughStyle: NSUnderlineStyle.single.rawValue,
                        .strikethroughColor: UIColor.white.withAlphaComponent(0.25),
                    ], nsRange: textRange, in: textView)
                }
                return
            }

            // List items - / *
            if line.hasPrefix("- ") || line.hasPrefix("* ") {
                let bulletRange = NSRange(location: range.location, length: 2)
                applyAttributes([
                    .foregroundColor: UIColor(red: 0.32, green: 0.90, blue: 0.55, alpha: 1.0),
                ], nsRange: bulletRange, in: textView)
            }

            // Markdown links [text](url) — but not image links ![text](url)
            applyMarkdownLinks(in: line, lineRange: range, textView: textView)

            // Bare URLs (https://... or http://...)
            applyBareURLLinks(in: line, lineRange: range, textView: textView)
        }

        private func applyMarkdownLinks(in line: String, lineRange: NSRange, textView: STTextView) {
            // Match [text](url) but not preceded by !
            let pattern = #"(?<!!)\[([^\]]+)\]\(([^)]+)\)"#
            guard let regex = try? NSRegularExpression(pattern: pattern) else { return }
            let nsLine = line as NSString
            let matches = regex.matches(in: line, range: NSRange(location: 0, length: nsLine.length))

            let hiddenFont = UIFont.monospacedSystemFont(ofSize: 0.01, weight: .regular)
            let hiddenAttrs: [NSAttributedString.Key: Any] = [
                .foregroundColor: UIColor.clear,
                .font: hiddenFont,
            ]

            for match in matches {
                let textRange = match.range(at: 1)
                let urlRange = match.range(at: 2)
                let urlString = nsLine.substring(with: urlRange)

                // Hide opening [
                let openBracket = NSRange(location: lineRange.location + match.range.location, length: 1)
                applyAttributes(hiddenAttrs, nsRange: openBracket, in: textView)

                // Style the link text
                let absoluteTextRange = NSRange(location: lineRange.location + textRange.location, length: textRange.length)
                let linkAttrs: [NSAttributedString.Key: Any] = [
                    .foregroundColor: UIColor(red: 0.45, green: 0.75, blue: 1.0, alpha: 1.0),
                    .underlineStyle: NSUnderlineStyle.single.rawValue,
                    .underlineColor: UIColor(red: 0.45, green: 0.75, blue: 1.0, alpha: 0.4),
                    .link: "hashy-url://\(urlString)",
                ]
                applyAttributes(linkAttrs, nsRange: absoluteTextRange, in: textView)

                // Hide ](url)
                let suffixStart = lineRange.location + textRange.location + textRange.length
                let suffixLength = match.range.length - textRange.length - 1 // -1 for the opening [
                let suffixRange = NSRange(location: suffixStart, length: suffixLength)
                applyAttributes(hiddenAttrs, nsRange: suffixRange, in: textView)
            }
        }

        private func applyBareURLLinks(in line: String, lineRange: NSRange, textView: STTextView) {
            let pattern = #"(?<!\(|"|')https?://[^\s\)\]>\"']+"#
            guard let regex = try? NSRegularExpression(pattern: pattern) else { return }
            let nsLine = line as NSString
            let matches = regex.matches(in: line, range: NSRange(location: 0, length: nsLine.length))

            for match in matches {
                let urlString = nsLine.substring(with: match.range)
                let absoluteRange = NSRange(location: lineRange.location + match.range.location, length: match.range.length)
                let linkAttrs: [NSAttributedString.Key: Any] = [
                    .foregroundColor: UIColor(red: 0.45, green: 0.75, blue: 1.0, alpha: 1.0),
                    .underlineStyle: NSUnderlineStyle.single.rawValue,
                    .underlineColor: UIColor(red: 0.45, green: 0.75, blue: 1.0, alpha: 0.4),
                    .link: "hashy-url://\(urlString)",
                ]
                applyAttributes(linkAttrs, nsRange: absoluteRange, in: textView)
            }
        }

        private func countLeadingHashes(_ line: String) -> Int {
            var count = 0
            for ch in line {
                if ch == "#" { count += 1 }
                else if ch == " " && count > 0 { return count }
                else { return 0 }
            }
            return 0
        }

        private func applyInlinePattern(_ pattern: String, in line: String, lineRange: NSRange, textView: STTextView, attrs: [NSAttributedString.Key: Any]) {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { return }
            let nsLine = line as NSString
            let matches = regex.matches(in: line, range: NSRange(location: 0, length: nsLine.length))
            for match in matches {
                let absoluteRange = NSRange(location: lineRange.location + match.range.location, length: match.range.length)
                applyAttributes(attrs, nsRange: absoluteRange, in: textView)
            }
        }

        private func applyAttributes(_ attrs: [NSAttributedString.Key: Any], nsRange: NSRange, in textView: STTextView) {
            textView.addAttributes(attrs, range: nsRange)
        }
    }
}

#endif

// MARK: - Wiki Link Resolver

/// Protocol for resolving wiki-link IDs to display information.
public protocol WikiLinkResolver {
    func resolve(id: String) -> WikiLinkResolution
}

public struct WikiLinkResolution {
    public let title: String?
    public let icon: String?
    public let typeName: String?

    public init(title: String? = nil, icon: String? = nil, typeName: String? = nil) {
        self.title = title
        self.icon = icon
        self.typeName = typeName
    }
}

// MARK: - Convenience Modifiers

public extension HashyEditorView {
    func onEmbedTrigger(_ action: @escaping (WikiLinkInsertion.Trigger) -> Void) -> HashyEditorView {
        var copy = self
        copy.onEmbedTrigger = action
        return copy
    }

    func onWikiLinkTrigger(_ action: @escaping () -> Void) -> HashyEditorView {
        var copy = self
        copy.onEmbedTrigger = { _ in action() }
        return copy
    }

    func onLinkClicked(_ action: @escaping (String) -> Void) -> HashyEditorView {
        var copy = self
        copy.onLinkClicked = action
        return copy
    }

    func onTextChange(_ action: @escaping (String) -> Void) -> HashyEditorView {
        var copy = self
        copy.onTextChange = action
        return copy
    }

    func wikiLinkResolver(_ resolver: WikiLinkResolver) -> HashyEditorView {
        var copy = self
        copy.wikiLinkResolver = resolver
        return copy
    }

    func editable(_ value: Bool) -> HashyEditorView {
        var copy = self
        copy.isEditable = value
        return copy
    }

    func lineNumbers(_ show: Bool) -> HashyEditorView {
        var copy = self
        copy.showLineNumbers = show
        return copy
    }

    func completionProvider(_ provider: @escaping (String) -> [HashyCompletionResult]) -> HashyEditorView {
        var copy = self
        copy.completionProvider = provider
        return copy
    }

    func showOverlayButtons(_ show: Bool) -> HashyEditorView {
        var copy = self
        copy.showOverlayButtons = show
        return copy
    }

    func onOverlayButtonTapped(_ action: @escaping (OverlayItem) -> Void) -> HashyEditorView {
        var copy = self
        copy.onOverlayButtonTapped = action
        return copy
    }

    func imageBaseURL(_ url: URL?) -> HashyEditorView {
        var copy = self
        copy.imageBaseURL = url
        return copy
    }

    func focusTrigger(_ value: Int) -> HashyEditorView {
        var copy = self
        copy.focusTrigger = value
        return copy
    }
}
