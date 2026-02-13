#if canImport(AppKit)
import AppKit
import STTextView

// MARK: - Completion Result

/// A completion result returned by the completionProvider closure.
public struct HashyCompletionResult: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let icon: String
    public let typeName: String

    public init(id: String, title: String, icon: String, typeName: String) {
        self.id = id
        self.title = title
        self.icon = icon
        self.typeName = typeName
    }
}

// MARK: - Completion Item View

/// An STCompletionItem that renders a HashyCompletionResult as an NSView
/// for display in the STTextView completion popup.
public class HashyCompletionItemView: NSObject, STCompletionItem, Identifiable {
    public let id: String
    public let result: HashyCompletionResult
    public let trigger: WikiLinkInsertion.Trigger

    public init(result: HashyCompletionResult, trigger: WikiLinkInsertion.Trigger) {
        self.id = result.id
        self.result = result
        self.trigger = trigger
        super.init()
    }

    public var view: NSView {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 220, height: 22))

        // Icon
        let iconView = NSImageView(frame: NSRect(x: 6, y: 3, width: 16, height: 16))
        if let image = NSImage(systemSymbolName: result.icon, accessibilityDescription: nil) {
            iconView.image = image
            iconView.contentTintColor = NSColor(red: 0.4, green: 0.7, blue: 1.0, alpha: 1.0)
        }
        iconView.imageScaling = .scaleProportionallyDown
        container.addSubview(iconView)

        // Title
        let titleField = NSTextField(labelWithString: result.title)
        titleField.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .medium)
        titleField.textColor = NSColor.white.withAlphaComponent(0.92)
        titleField.frame = NSRect(x: 28, y: 3, width: 140, height: 16)
        titleField.lineBreakMode = .byTruncatingTail
        container.addSubview(titleField)

        // Type badge
        let typeField = NSTextField(labelWithString: result.typeName)
        typeField.font = NSFont.monospacedSystemFont(ofSize: 9, weight: .regular)
        typeField.textColor = NSColor.white.withAlphaComponent(0.4)
        typeField.alignment = .right
        typeField.frame = NSRect(x: 170, y: 4, width: 44, height: 14)
        typeField.lineBreakMode = .byTruncatingTail
        container.addSubview(typeField)

        return container
    }
}

#else

import Foundation

// MARK: - Completion Result (iOS)

/// A completion result returned by the completionProvider closure.
public struct HashyCompletionResult: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let icon: String
    public let typeName: String

    public init(id: String, title: String, icon: String, typeName: String) {
        self.id = id
        self.title = title
        self.icon = icon
        self.typeName = typeName
    }
}

#endif
