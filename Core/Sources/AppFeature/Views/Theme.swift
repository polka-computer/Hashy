import SwiftUI

// MARK: - Theme

/// Minimal, dark terminal theme
public enum Theme {
    // MARK: - Colors

    /// Pure black background
    public static let background = Color.black

    /// Slightly lighter black for panels (nearly invisible difference)
    public static let backgroundSecondary = Color(white: 0.02)

    /// Even lighter for tertiary elements (subtle hover states)
    public static let backgroundTertiary = Color(white: 0.05)

    /// Subtle border color
    public static let border = Color(white: 0.08)

    /// Stronger border for emphasis
    public static let borderStrong = Color(white: 0.12)

    /// Primary text - bright white
    public static let text = Color(white: 0.92)

    /// Dimmed text for secondary content
    public static let textDim = Color(white: 0.55)

    /// Very dim text for tertiary content
    public static let textMuted = Color(white: 0.35)

    /// Accent color - vibrant green
    public static let accent = Color(red: 0.32, green: 0.90, blue: 0.55)

    /// Dimmed accent
    public static let accentDim = Color(red: 0.22, green: 0.64, blue: 0.43)

    /// Active tab/selection background
    public static let selection = Color(white: 0.06)

    // MARK: - Semantic Colors

    /// Success/completed state
    public static let success = Color(red: 0.30, green: 0.85, blue: 0.45)

    /// Warning state
    public static let warning = Color(red: 0.95, green: 0.75, blue: 0.25)

    /// Error state
    public static let error = Color(red: 0.95, green: 0.35, blue: 0.35)

    /// Info/thinking state
    public static let info = Color(red: 0.45, green: 0.65, blue: 0.95)

    /// In-progress state
    public static let inProgress = Color(red: 0.95, green: 0.75, blue: 0.25)

    // MARK: - Fonts (Monaspace Nerd Font)
    // Note: Uses PostScript names (MonaspiceNeNFM-*), not filenames

    /// Primary monospace font
    public static let mono = Font.custom("MonaspiceNeNFM-Regular", size: 13)

    /// Small monospace font
    public static let monoSmall = Font.custom("MonaspiceNeNFM-Regular", size: 11)

    /// Extra small monospace font
    public static let monoXSmall = Font.custom("MonaspiceNeNFM-Regular", size: 10)

    /// Bold monospace font
    public static let monoBold = Font.custom("MonaspiceNeNFM-Bold", size: 13)

    /// Large monospace font for headers
    public static let monoLarge = Font.custom("MonaspiceNeNFM-Bold", size: 15)

    /// Title font
    public static let monoTitle = Font.custom("MonaspiceNeNFM-Bold", size: 18)

    /// Italic font for emphasis
    public static let monoItalic = Font.custom("MonaspiceNeNFM-Italic", size: 13)

    /// Bold italic font
    public static let monoBoldItalic = Font.custom("MonaspiceNeNFM-BoldItalic", size: 13)

    /// Medium weight font
    public static let monoMedium = Font.custom("MonaspiceNeNFM-Medium", size: 13)

    /// Light weight font
    public static let monoLight = Font.custom("MonaspiceNeNFM-Light", size: 13)

    // MARK: - Spacing

    /// Base spacing unit
    public static let spacing: CGFloat = 8

    /// Small spacing
    public static let spacingSmall: CGFloat = 4

    /// Extra small spacing
    public static let spacingXSmall: CGFloat = 2

    /// Large spacing
    public static let spacingLarge: CGFloat = 16

    // MARK: - Border Radius

    /// Default corner radius (sharp for terminal look)
    public static let cornerRadius: CGFloat = 0

    /// Small corner radius
    public static let cornerRadiusSmall: CGFloat = 0

    // MARK: - Animation

    /// Default animation duration
    public static let animationDuration: Double = 0.15

    /// Standard animation
    public static let animation: Animation = .easeOut(duration: animationDuration)
}

// MARK: - View Extensions

extension View {
    /// Apply terminal background
    public func terminalBackground() -> some View {
        self.background(Theme.background)
    }

    /// Apply terminal text style
    public func terminalText() -> some View {
        self
            .font(Theme.mono)
            .foregroundStyle(Theme.text)
    }

    /// Apply dimmed terminal text style
    public func terminalTextDim() -> some View {
        self
            .font(Theme.mono)
            .foregroundStyle(Theme.textDim)
    }

    /// Apply muted terminal text style
    public func terminalTextMuted() -> some View {
        self
            .font(Theme.monoSmall)
            .foregroundStyle(Theme.textMuted)
    }

    /// Apply terminal border
    public func terminalBorder() -> some View {
        self.overlay(
            Rectangle()
                .stroke(Theme.border, lineWidth: 1)
        )
    }

    /// Apply terminal selection style
    public func terminalSelection(_ isSelected: Bool) -> some View {
        self.background(isSelected ? Theme.selection : Color.clear)
    }
}
