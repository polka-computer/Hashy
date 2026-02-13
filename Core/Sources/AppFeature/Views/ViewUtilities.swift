import SwiftUI

#if canImport(AppKit)
import AppKit
#endif

// MARK: - Color Extension

public extension Color {
    static let hashyAccent = Color("AccentColor")

    init(hex: UInt, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xff) / 255,
            green: Double((hex >> 08) & 0xff) / 255,
            blue: Double((hex >> 00) & 0xff) / 255,
            opacity: alpha
        )
    }
}

// MARK: - Conditional Hidden Helper

public extension View {
    @ViewBuilder
    func hidden(_ shouldHide: Bool) -> some View {
        if shouldHide { self.hidden() } else { self }
    }
}

// MARK: - macOS-only Utilities

#if canImport(AppKit)

// MARK: - Pointer Hand Cursor Modifier

struct PointerHandCursor: ViewModifier {
    @Environment(\.cursorInteractionsEnabled) private var cursorInteractionsEnabled
    @State private var isHovering = false

    func body(content: Content) -> some View {
        content
            .onHover { hovering in
                guard cursorInteractionsEnabled else { return }
                isHovering = hovering
                if hovering {
                    NSCursor.pointingHand.push()
                } else {
                    NSCursor.pop()
                }
            }
    }
}

public extension View {
    func pointerHandCursor() -> some View {
        self.modifier(PointerHandCursor())
    }
}

// MARK: - Cursor Interactions Environment Key

private struct CursorInteractionsEnabledKey: EnvironmentKey {
    static let defaultValue: Bool = true
}

public extension EnvironmentValues {
    var cursorInteractionsEnabled: Bool {
        get { self[CursorInteractionsEnabledKey.self] }
        set { self[CursorInteractionsEnabledKey.self] = newValue }
    }
}

// MARK: - Neon Scrollbar

public class NeonScroller: NSScroller {
    public var neonColor: NSColor = NSColor(red: 0.32, green: 0.90, blue: 0.47, alpha: 1.0)

    override public class func scrollerWidth(
        for controlSize: NSControl.ControlSize,
        scrollerStyle: NSScroller.Style
    ) -> CGFloat {
        return 5
    }

    override public func drawKnob() {
        let knobRect = rect(for: .knob).insetBy(dx: 0.5, dy: 0.5)
        let cornerRadius = min(knobRect.width, knobRect.height) / 2
        let path = NSBezierPath(roundedRect: knobRect, xRadius: cornerRadius, yRadius: cornerRadius)
        neonColor.setFill()
        path.fill()
    }

    override public func drawKnobSlot(in slotRect: NSRect, highlight flag: Bool) {
        // Don't draw slot — transparent background
    }
}

#else

// MARK: - iOS stubs

public extension View {
    func pointerHandCursor() -> some View {
        self
    }
}

#endif

