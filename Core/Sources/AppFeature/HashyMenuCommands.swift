import ComposableArchitecture
import SwiftUI

/// Menu commands for the markdown editor.
public struct HashyMenuCommands: Commands {
    let store: StoreOf<AppFeature>

    public init(store: StoreOf<AppFeature>) {
        self.store = store
    }

    public var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Note") {
                store.send(.createNewNote)
            }
            .keyboardShortcut("n", modifiers: .command)
        }

        CommandGroup(replacing: .saveItem) {
            Button("Save") {
                store.send(.saveCurrentFile)
            }
            .keyboardShortcut("s", modifiers: .command)
        }

        CommandGroup(replacing: .appSettings) {
            Button("Settings...") {
                store.send(.setSettingsVisible(true))
            }
            .keyboardShortcut(",", modifiers: .command)
        }

        CommandGroup(after: .sidebar) {
            Button("Find Note") {
                store.send(.focusSearch)
            }
            .keyboardShortcut("k", modifiers: .command)

            Divider()

            Button("Toggle Sidebar") {
                store.send(.toggleSidebar)
            }
            .keyboardShortcut("\\", modifiers: .command)

            Button("AI Chat") {
                store.send(.toggleChat)
            }
            .keyboardShortcut("l", modifiers: .command)

            Divider()

            Button("Zen Mode") {
                store.send(.toggleZenMode)
            }
            .keyboardShortcut("f", modifiers: [.command, .shift])

            Divider()

            Button("Previous Note") {
                store.send(.selectPreviousFile)
                store.send(.focusEditor)
            }
            .keyboardShortcut(.upArrow, modifiers: .option)

            Button("Next Note") {
                store.send(.selectNextFile)
                store.send(.focusEditor)
            }
            .keyboardShortcut(.downArrow, modifiers: .option)

            Divider()

            Button("Back") {
                store.send(.navigateBack)
            }
            .keyboardShortcut("[", modifiers: .command)

            Button("Forward") {
                store.send(.navigateForward)
            }
            .keyboardShortcut("]", modifiers: .command)

            Divider()

            Button("Delete Note") {
                store.send(.deleteCurrentNote)
            }
            .keyboardShortcut(.delete, modifiers: [.command, .shift])
        }

        CommandGroup(replacing: .help) {
            Link("GitHub", destination: URL(string: "https://github.com/polka-computer/Hashy")!)
            Link("Discord", destination: URL(string: "https://discord.gg/zwpnkxETJ3")!)
        }
    }
}
