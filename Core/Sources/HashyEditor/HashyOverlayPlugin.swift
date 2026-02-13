// MARK: - Hashy Overlay Plugin
//
// STTextView plugin that adds interactive overlay buttons next to:
// - Links (globe icon)
// - Lists/Tasks (play icon)

#if canImport(AppKit)
import AppKit
@_exported import STTextView

// MARK: - Overlay Item Types

/// Represents a detected item that should have an overlay button
public struct OverlayItem: Equatable, Hashable {
    public enum Kind: Equatable, Hashable {
        case link(url: String)      // Wiki-link or URL
        case listItem               // Regular list item (- or *)
        case task(isChecked: Bool)  // Todo checkbox
    }

    public let kind: Kind
    public let lineRange: NSRange  // Range of the entire line
    public let location: Int       // Character offset in document

    public static func == (lhs: OverlayItem, rhs: OverlayItem) -> Bool {
        lhs.location == rhs.location && lhs.lineRange == rhs.lineRange
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(location)
        hasher.combine(lineRange.location)
    }
}

// MARK: - Overlay Button Actions

public protocol OverlayButtonDelegate: AnyObject {
    func overlayButtonTapped(item: OverlayItem)
}

// MARK: - Plugin Implementation

@MainActor
public class HashyOverlayPlugin: STPlugin {
    public typealias Coordinator = OverlayCoordinator

    public weak var delegate: OverlayButtonDelegate?

    /// Whether to show globe buttons next to links
    public var showLinkButtons: Bool = true

    /// Whether to show play buttons next to list items
    public var showListButtons: Bool = true

    public init(delegate: OverlayButtonDelegate? = nil) {
        self.delegate = delegate
    }

    public func makeCoordinator(context: STPluginCoordinatorContext) -> OverlayCoordinator {
        OverlayCoordinator(plugin: self, textView: context.textView)
    }

    public func setUp(context: any PluginContext<HashyOverlayPlugin>) {
        let coordinator = context.coordinator

        context.events
            .onDidLayoutViewport { visibleRange in
                coordinator.updateOverlays(visibleRange: visibleRange)
            }
            .onDidChangeText { _, _ in
                coordinator.scheduleUpdate()
            }
    }

    public func tearDown() {
        // Cleanup handled by coordinator
    }
}

// MARK: - Coordinator

@MainActor
public class OverlayCoordinator {
    private weak var plugin: HashyOverlayPlugin?
    private weak var textView: STTextView?

    /// Currently displayed overlay buttons keyed by item location
    private var overlayButtons: [Int: NSButton] = [:]

    /// Debounce timer for updates
    nonisolated(unsafe) private var updateTimer: Timer?

    init(plugin: HashyOverlayPlugin, textView: STTextView) {
        self.plugin = plugin
        self.textView = textView
    }

    deinit {
        updateTimer?.invalidate()
    }

    // MARK: - Update Scheduling

    func scheduleUpdate() {
        updateTimer?.invalidate()
        updateTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.updateOverlays(visibleRange: nil)
            }
        }
    }

    // MARK: - Overlay Management

    func updateOverlays(visibleRange: NSTextRange?) {
        guard let textView = textView,
              let text = textView.text,
              !text.isEmpty else {
            removeAllOverlays()
            return
        }

        let showLinks = plugin?.showLinkButtons ?? true
        let showLists = plugin?.showListButtons ?? true
        let items = detectOverlayItems(in: text, showLinks: showLinks, showLists: showLists)

        // Remove buttons for items that no longer exist
        let currentLocations = Set(items.map { $0.location })
        let buttonsToRemove = overlayButtons.keys.filter { !currentLocations.contains($0) }
        for location in buttonsToRemove {
            overlayButtons[location]?.removeFromSuperview()
            overlayButtons.removeValue(forKey: location)
        }

        // Add or update buttons for each item
        for item in items {
            updateOrCreateButton(for: item)
        }
    }

    private func removeAllOverlays() {
        for button in overlayButtons.values {
            button.removeFromSuperview()
        }
        overlayButtons.removeAll()
    }

    // MARK: - Item Detection

    private func detectOverlayItems(in text: String, showLinks: Bool, showLists: Bool) -> [OverlayItem] {
        var items: [OverlayItem] = []
        let nsText = text as NSString

        nsText.enumerateSubstrings(
            in: NSRange(location: 0, length: nsText.length),
            options: [.byLines, .substringNotRequired]
        ) { _, lineRange, _, _ in
            let line = nsText.substring(with: lineRange)

            // Detect wiki-links on this line
            if showLinks {
                items.append(contentsOf: self.detectLinks(in: line, lineRange: lineRange))
            }

            // Detect list items and tasks
            if showLists {
                if let listItem = self.detectListOrTask(in: line, lineRange: lineRange) {
                    items.append(listItem)
                }
            }
        }

        return items
    }

    private func detectLinks(in line: String, lineRange: NSRange) -> [OverlayItem] {
        var items: [OverlayItem] = []

        // Wiki-link pattern: [[id]] or [[id|name]]
        let wikiPattern = #"\[\[([^\]|]+)(?:\|[^\]]+)?\]\]"#
        if let regex = try? NSRegularExpression(pattern: wikiPattern) {
            let nsLine = line as NSString
            let matches = regex.matches(in: line, range: NSRange(location: 0, length: nsLine.length))
            for match in matches {
                let targetId = nsLine.substring(with: match.range(at: 1))
                let absoluteLocation = lineRange.location + match.range.location
                items.append(OverlayItem(
                    kind: .link(url: "hashy-link://\(targetId)"),
                    lineRange: lineRange,
                    location: absoluteLocation
                ))
            }
        }

        // URL pattern (http/https)
        let urlPattern = #"https?://[^\s\])]+"#
        if let regex = try? NSRegularExpression(pattern: urlPattern) {
            let nsLine = line as NSString
            let matches = regex.matches(in: line, range: NSRange(location: 0, length: nsLine.length))
            for match in matches {
                let url = nsLine.substring(with: match.range)
                let absoluteLocation = lineRange.location + match.range.location
                items.append(OverlayItem(
                    kind: .link(url: url),
                    lineRange: lineRange,
                    location: absoluteLocation
                ))
            }
        }

        return items
    }

    private func detectListOrTask(in line: String, lineRange: NSRange) -> OverlayItem? {
        if line.hasPrefix("- [ ] ") {
            return OverlayItem(kind: .task(isChecked: false), lineRange: lineRange, location: lineRange.location)
        }

        if line.hasPrefix("- [x] ") || line.hasPrefix("- [X] ") {
            return OverlayItem(kind: .task(isChecked: true), lineRange: lineRange, location: lineRange.location)
        }

        if line.hasPrefix("- ") || line.hasPrefix("* ") {
            return OverlayItem(kind: .listItem, lineRange: lineRange, location: lineRange.location)
        }

        return nil
    }

    // MARK: - Button Creation and Positioning

    private func updateOrCreateButton(for item: OverlayItem) {
        guard let textView = textView else { return }

        guard let buttonFrame = frameForItem(item) else {
            overlayButtons[item.location]?.removeFromSuperview()
            overlayButtons.removeValue(forKey: item.location)
            return
        }

        let button: NSButton
        if let existingButton = overlayButtons[item.location] {
            button = existingButton
        } else {
            button = createButton(for: item)
            overlayButtons[item.location] = button
            textView.addSubview(button)
        }

        button.frame = buttonFrame
    }

    private func createButton(for item: OverlayItem) -> NSButton {
        let button = NSButton(frame: .zero)
        button.bezelStyle = .inline
        button.isBordered = false
        button.wantsLayer = true
        button.layer?.cornerRadius = 4

        switch item.kind {
        case .link:
            button.image = NSImage(systemSymbolName: "globe", accessibilityDescription: "Open link")
            button.contentTintColor = NSColor(red: 0.45, green: 0.75, blue: 1.0, alpha: 1.0)
            button.toolTip = "Open link"
        case .listItem:
            button.image = NSImage(systemSymbolName: "play.fill", accessibilityDescription: "Run item")
            button.contentTintColor = NSColor(red: 0.32, green: 0.90, blue: 0.55, alpha: 1.0)
            button.toolTip = "Run"
        case .task(let isChecked):
            button.image = NSImage(systemSymbolName: "play.fill", accessibilityDescription: "Run task")
            button.contentTintColor = isChecked
                ? NSColor(white: 0.5, alpha: 1.0)
                : NSColor(red: 0.32, green: 0.90, blue: 0.55, alpha: 1.0)
            button.toolTip = "Run task"
        }

        button.tag = item.location
        button.target = self
        button.action = #selector(buttonTapped(_:))
        button.alphaValue = 0.6

        return button
    }

    @objc private func buttonTapped(_ sender: NSButton) {
        guard let textView = textView,
              let text = textView.text else { return }

        let location = sender.tag
        let showLinks = plugin?.showLinkButtons ?? true
        let showLists = plugin?.showListButtons ?? true
        let items = detectOverlayItems(in: text, showLinks: showLinks, showLists: showLists)
        if let item = items.first(where: { $0.location == location }) {
            plugin?.delegate?.overlayButtonTapped(item: item)
        }
    }

    private func frameForItem(_ item: OverlayItem) -> CGRect? {
        guard let textView = textView else { return nil }

        let textLayoutManager = textView.textLayoutManager
        let textContentManager = textView.textContentManager
        let docStart = textContentManager.documentRange.location

        guard let lineStartLocation = textContentManager.location(docStart, offsetBy: item.lineRange.location),
              let lineEndLocation = textContentManager.location(docStart, offsetBy: item.lineRange.location + item.lineRange.length),
              let _ = NSTextRange(location: lineStartLocation, end: lineEndLocation) else {
            return nil
        }

        var lineFrame: CGRect?
        textLayoutManager.enumerateTextLayoutFragments(
            from: lineStartLocation,
            options: [.ensuresLayout]
        ) { layoutFragment in
            for textLineFragment in layoutFragment.textLineFragments {
                let lineFragmentFrame = layoutFragment.layoutFragmentFrame
                lineFrame = CGRect(
                    x: lineFragmentFrame.maxX + 8,
                    y: lineFragmentFrame.origin.y + textLineFragment.typographicBounds.minY,
                    width: 20,
                    height: textLineFragment.typographicBounds.height
                )
                return false
            }
            return false
        }

        return lineFrame
    }
}

#elseif canImport(UIKit)

// MARK: - iOS Overlay Plugin

import UIKit
@_exported import STTextView

/// Represents a detected item that should have an overlay button
public struct OverlayItem: Equatable, Hashable {
    public enum Kind: Equatable, Hashable {
        case link(url: String)      // Wiki-link or URL
        case listItem               // Regular list item (- or *)
        case task(isChecked: Bool)  // Todo checkbox
    }

    public let kind: Kind
    public let lineRange: NSRange  // Range of the entire line
    public let location: Int       // Character offset in document

    public static func == (lhs: OverlayItem, rhs: OverlayItem) -> Bool {
        lhs.location == rhs.location && lhs.lineRange == rhs.lineRange
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(location)
        hasher.combine(lineRange.location)
    }
}

// MARK: - Overlay Button Actions

public protocol OverlayButtonDelegate: AnyObject {
    func overlayButtonTapped(item: OverlayItem)
}

// MARK: - Plugin Implementation

@MainActor
public class HashyOverlayPlugin: STPlugin {
    public typealias Coordinator = OverlayCoordinator

    public weak var delegate: OverlayButtonDelegate?

    /// Whether to show globe buttons next to links
    public var showLinkButtons: Bool = true

    /// Whether to show play buttons next to list items
    public var showListButtons: Bool = true

    public init(delegate: OverlayButtonDelegate? = nil) {
        self.delegate = delegate
    }

    public func makeCoordinator(context: STPluginCoordinatorContext) -> OverlayCoordinator {
        OverlayCoordinator(plugin: self, textView: context.textView)
    }

    public func setUp(context: any PluginContext<HashyOverlayPlugin>) {
        let coordinator = context.coordinator

        context.events
            .onDidLayoutViewport { visibleRange in
                coordinator.updateOverlays(visibleRange: visibleRange)
            }
            .onDidChangeText { _, _ in
                coordinator.scheduleUpdate()
            }
    }

    public func tearDown() {
        // Cleanup handled by coordinator
    }
}

// MARK: - Coordinator

@MainActor
public class OverlayCoordinator {
    private weak var plugin: HashyOverlayPlugin?
    private weak var textView: STTextView?

    /// Currently displayed overlay buttons keyed by item location
    private var overlayButtons: [Int: UIButton] = [:]

    /// Debounce timer for updates
    nonisolated(unsafe) private var updateTimer: Timer?

    init(plugin: HashyOverlayPlugin, textView: STTextView) {
        self.plugin = plugin
        self.textView = textView
    }

    deinit {
        updateTimer?.invalidate()
    }

    // MARK: - Update Scheduling

    func scheduleUpdate() {
        updateTimer?.invalidate()
        updateTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.updateOverlays(visibleRange: nil)
            }
        }
    }

    // MARK: - Overlay Management

    func updateOverlays(visibleRange: NSTextRange?) {
        guard let textView = textView,
              let text = textView.text,
              !text.isEmpty else {
            removeAllOverlays()
            return
        }

        let showLinks = plugin?.showLinkButtons ?? true
        let showLists = plugin?.showListButtons ?? true
        let items = detectOverlayItems(in: text, showLinks: showLinks, showLists: showLists)

        // Remove buttons for items that no longer exist
        let currentLocations = Set(items.map { $0.location })
        let buttonsToRemove = overlayButtons.keys.filter { !currentLocations.contains($0) }
        for location in buttonsToRemove {
            overlayButtons[location]?.removeFromSuperview()
            overlayButtons.removeValue(forKey: location)
        }

        // Add or update buttons for each item
        for item in items {
            updateOrCreateButton(for: item)
        }
    }

    private func removeAllOverlays() {
        for button in overlayButtons.values {
            button.removeFromSuperview()
        }
        overlayButtons.removeAll()
    }

    // MARK: - Item Detection

    private func detectOverlayItems(in text: String, showLinks: Bool, showLists: Bool) -> [OverlayItem] {
        var items: [OverlayItem] = []
        let nsText = text as NSString

        nsText.enumerateSubstrings(
            in: NSRange(location: 0, length: nsText.length),
            options: [.byLines, .substringNotRequired]
        ) { _, lineRange, _, _ in
            let line = nsText.substring(with: lineRange)

            // Detect wiki-links on this line
            if showLinks {
                items.append(contentsOf: self.detectLinks(in: line, lineRange: lineRange))
            }

            // Detect list items and tasks
            if showLists {
                if let listItem = self.detectListOrTask(in: line, lineRange: lineRange) {
                    items.append(listItem)
                }
            }
        }

        return items
    }

    private func detectLinks(in line: String, lineRange: NSRange) -> [OverlayItem] {
        var items: [OverlayItem] = []

        // Wiki-link pattern: [[id]] or [[id|name]]
        let wikiPattern = #"\[\[([^\]|]+)(?:\|[^\]]+)?\]\]"#
        if let regex = try? NSRegularExpression(pattern: wikiPattern) {
            let nsLine = line as NSString
            let matches = regex.matches(in: line, range: NSRange(location: 0, length: nsLine.length))
            for match in matches {
                let targetId = nsLine.substring(with: match.range(at: 1))
                let absoluteLocation = lineRange.location + match.range.location
                items.append(OverlayItem(
                    kind: .link(url: "hashy-link://\(targetId)"),
                    lineRange: lineRange,
                    location: absoluteLocation
                ))
            }
        }

        // URL pattern (http/https)
        let urlPattern = #"https?://[^\s\])]+"#
        if let regex = try? NSRegularExpression(pattern: urlPattern) {
            let nsLine = line as NSString
            let matches = regex.matches(in: line, range: NSRange(location: 0, length: nsLine.length))
            for match in matches {
                let url = nsLine.substring(with: match.range)
                let absoluteLocation = lineRange.location + match.range.location
                items.append(OverlayItem(
                    kind: .link(url: url),
                    lineRange: lineRange,
                    location: absoluteLocation
                ))
            }
        }

        return items
    }

    private func detectListOrTask(in line: String, lineRange: NSRange) -> OverlayItem? {
        if line.hasPrefix("- [ ] ") {
            return OverlayItem(kind: .task(isChecked: false), lineRange: lineRange, location: lineRange.location)
        }

        if line.hasPrefix("- [x] ") || line.hasPrefix("- [X] ") {
            return OverlayItem(kind: .task(isChecked: true), lineRange: lineRange, location: lineRange.location)
        }

        if line.hasPrefix("- ") || line.hasPrefix("* ") {
            return OverlayItem(kind: .listItem, lineRange: lineRange, location: lineRange.location)
        }

        return nil
    }

    // MARK: - Button Creation and Positioning

    private func updateOrCreateButton(for item: OverlayItem) {
        guard let textView = textView else { return }

        guard let buttonFrame = frameForItem(item) else {
            overlayButtons[item.location]?.removeFromSuperview()
            overlayButtons.removeValue(forKey: item.location)
            return
        }

        let button: UIButton
        if let existingButton = overlayButtons[item.location] {
            button = existingButton
        } else {
            button = createButton(for: item)
            overlayButtons[item.location] = button
            textView.addSubview(button)
        }

        button.frame = buttonFrame
    }

    private func createButton(for item: OverlayItem) -> UIButton {
        let button = UIButton(type: .system)
        button.layer.cornerRadius = 4

        switch item.kind {
        case .link:
            button.setImage(UIImage(systemName: "globe"), for: .normal)
            button.tintColor = UIColor(red: 0.45, green: 0.75, blue: 1.0, alpha: 1.0)
        case .listItem:
            button.setImage(UIImage(systemName: "play.fill"), for: .normal)
            button.tintColor = UIColor(red: 0.32, green: 0.90, blue: 0.55, alpha: 1.0)
        case .task(let isChecked):
            button.setImage(UIImage(systemName: "play.fill"), for: .normal)
            button.tintColor = isChecked
                ? UIColor(white: 0.5, alpha: 1.0)
                : UIColor(red: 0.32, green: 0.90, blue: 0.55, alpha: 1.0)
        }

        button.tag = item.location
        button.addTarget(self, action: #selector(buttonTapped(_:)), for: .touchUpInside)
        button.alpha = 0.6

        return button
    }

    @objc private func buttonTapped(_ sender: UIButton) {
        guard let textView = textView,
              let text = textView.text else { return }

        let location = sender.tag
        let showLinks = plugin?.showLinkButtons ?? true
        let showLists = plugin?.showListButtons ?? true
        let items = detectOverlayItems(in: text, showLinks: showLinks, showLists: showLists)
        if let item = items.first(where: { $0.location == location }) {
            plugin?.delegate?.overlayButtonTapped(item: item)
        }
    }

    private func frameForItem(_ item: OverlayItem) -> CGRect? {
        guard let textView = textView else { return nil }

        let textLayoutManager = textView.textLayoutManager
        let textContentManager = textView.textContentManager
        let docStart = textContentManager.documentRange.location

        guard let lineStartLocation = textContentManager.location(docStart, offsetBy: item.lineRange.location),
              let lineEndLocation = textContentManager.location(docStart, offsetBy: item.lineRange.location + item.lineRange.length),
              let _ = NSTextRange(location: lineStartLocation, end: lineEndLocation) else {
            return nil
        }

        var lineFrame: CGRect?
        textLayoutManager.enumerateTextLayoutFragments(
            from: lineStartLocation,
            options: [.ensuresLayout]
        ) { layoutFragment in
            for textLineFragment in layoutFragment.textLineFragments {
                let lineFragmentFrame = layoutFragment.layoutFragmentFrame
                lineFrame = CGRect(
                    x: lineFragmentFrame.maxX + 8,
                    y: lineFragmentFrame.origin.y + textLineFragment.typographicBounds.minY,
                    width: 20,
                    height: textLineFragment.typographicBounds.height
                )
                return false
            }
            return false
        }

        return lineFrame
    }
}

#endif
