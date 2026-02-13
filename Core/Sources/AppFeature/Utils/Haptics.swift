import Foundation

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

enum Haptics {
    enum Style {
        case light
        case medium
        case selection
        case success
        case warning
    }

    @MainActor
    static func play(_ style: Style) {
        #if os(iOS)
        switch style {
        case .light:
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case .medium:
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        case .selection:
            UISelectionFeedbackGenerator().selectionChanged()
        case .success:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        case .warning:
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        }
        #elseif os(macOS)
        let performer = NSHapticFeedbackManager.defaultPerformer
        switch style {
        case .light, .selection:
            performer.perform(.levelChange, performanceTime: .now)
        case .medium:
            performer.perform(.generic, performanceTime: .now)
        case .success:
            performer.perform(.levelChange, performanceTime: .now)
        case .warning:
            performer.perform(.alignment, performanceTime: .now)
        }
        #endif
    }
}
