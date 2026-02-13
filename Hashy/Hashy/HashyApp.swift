import AppFeature
import ComposableArchitecture
import SwiftUI

#if canImport(AppKit)
import AppKit
#endif

@main
struct HashyApp: App {
    static let store: StoreOf<AppFeature> = Store(
        initialState: AppFeature.State()
    ) {
        AppFeature()
    }

    init() {
        #if canImport(AppKit)
        NSWindow.allowsAutomaticWindowTabbing = false
        #endif
        FontRegistration.registerFonts()
    }

    var body: some Scene {
        WindowGroup {
            HashyMainView(store: Self.store)
                .preferredColorScheme(Self.store.isDarkMode ? .dark : .light)
        }
        #if os(macOS)
        .commands {
            HashyMenuCommands(store: Self.store)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1600, height: 1000)
        .defaultPosition(.center)
        #endif
    }
}
