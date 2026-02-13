import SwiftUI
import CoreText

/// Registers custom fonts from the app bundle
public enum FontRegistration {
    /// Monaspace Nerd Font variants (Neon style - Mono)
    private static let fonts: [(name: String, ext: String)] = [
        ("MonaspiceNeNerdFontMono-Regular", "otf"),
        ("MonaspiceNeNerdFontMono-Italic", "otf"),
        ("MonaspiceNeNerdFontMono-Bold", "otf"),
        ("MonaspiceNeNerdFontMono-BoldItalic", "otf"),
        ("MonaspiceNeNerdFontMono-Medium", "otf"),
        ("MonaspiceNeNerdFontMono-MediumItalic", "otf"),
        ("MonaspiceNeNerdFontMono-Light", "otf"),
        ("MonaspiceNeNerdFontMono-LightItalic", "otf"),
    ]

    /// Call this once at app startup to register all custom fonts
    public static func registerFonts() {
        for font in fonts {
            registerFont(named: font.name, extension: font.ext)
        }
    }

    private static func registerFont(named name: String, extension ext: String) {
        // Try Bundle.module (for SPM resources), then main bundle
        let url = Bundle.module.url(forResource: name, withExtension: ext, subdirectory: "Monaspace")
            ?? Bundle.module.url(forResource: name, withExtension: ext)
            ?? Bundle.main.url(forResource: name, withExtension: ext, subdirectory: "Monaspace")
            ?? Bundle.main.url(forResource: name, withExtension: ext)

        guard let url else {
            print("[Fonts] Font file not found: \(name).\(ext)")
            return
        }

        var error: Unmanaged<CFError>?
        if !CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error) {
            // Font might already be registered, which is fine
            let errorDesc = error?.takeRetainedValue().localizedDescription ?? "unknown"
            if !errorDesc.contains("already registered") {
                print("[Fonts] Failed to register font \(name): \(errorDesc)")
            }
        }
    }
}

// MARK: - Monaspace Nerd Font

extension Font {
    /// Monaspace Nerd Font - A custom monospace font with Nerd Font glyphs
    /// Note: Uses PostScript names (MonaspiceNeNFM-*), not filenames
    public static func monaspace(_ size: CGFloat, weight: Weight = .regular) -> Font {
        let fontName: String
        switch weight {
        case .bold, .heavy, .black:
            fontName = "MonaspiceNeNFM-Bold"
        case .semibold, .medium:
            fontName = "MonaspiceNeNFM-Medium"
        case .light, .ultraLight, .thin:
            fontName = "MonaspiceNeNFM-Light"
        default:
            fontName = "MonaspiceNeNFM-Regular"
        }
        return .custom(fontName, size: size)
    }

    /// Monaspace italic variant
    public static func monaspaceItalic(_ size: CGFloat, weight: Weight = .regular) -> Font {
        let fontName: String
        switch weight {
        case .bold, .heavy, .black:
            fontName = "MonaspiceNeNFM-BoldItalic"
        case .semibold, .medium:
            fontName = "MonaspiceNeNFM-MediumItalic"
        case .light, .ultraLight, .thin:
            fontName = "MonaspiceNeNFM-LightItalic"
        default:
            fontName = "MonaspiceNeNFM-Italic"
        }
        return .custom(fontName, size: size)
    }
}
