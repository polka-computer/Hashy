import ComposableArchitecture
import MarkdownStorage
import SwiftUI

/// Settings popover for vault location, API key, and model selection.
struct SettingsView: View {
    @Bindable var store: StoreOf<AppFeature>
    @State private var customModelInput: String = ""
    #if os(iOS)
    @State private var showFolderPicker = false
    #endif

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Settings")
                    .font(Theme.monoBold)
                    .foregroundStyle(Theme.text)

                Divider().background(Theme.border)

                // Vault
                VStack(alignment: .leading, spacing: 4) {
                    Text("Vault")
                        .font(Theme.monoXSmall)
                        .foregroundStyle(Theme.textDim)

                    Text(store.vaultPath)
                        .font(Theme.monoXSmall)
                        .foregroundStyle(Theme.text)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(6)
                        .background(Theme.backgroundTertiary)

                    HStack(spacing: 6) {
                        #if os(macOS)
                        Button("Reveal in Finder") {
                            Haptics.play(.light)
                            store.send(.revealVaultInFinder)
                        }
                        .font(Theme.monoXSmall)
                        #endif

                        Button("Change Folder...") {
                            Haptics.play(.light)
                            #if os(macOS)
                            store.send(.chooseVaultFolder)
                            #else
                            showFolderPicker = true
                            #endif
                        }
                        .font(Theme.monoXSmall)

                        if CloudContainerProvider.isUsingCustomDirectory {
                            Button("Reset to Default") {
                                Haptics.play(.warning)
                                store.send(.resetVaultFolder)
                            }
                            .font(Theme.monoXSmall)
                            .foregroundStyle(.red)
                        }
                    }
                }

                Divider().background(Theme.border)

                // Sync diagnostics
                VStack(alignment: .leading, spacing: 4) {
                    Text("Sync")
                        .font(Theme.monoXSmall)
                        .foregroundStyle(Theme.textDim)

                    Text(CloudContainerProvider.isCloudAvailable ? "iCloud Drive connected" : "iCloud Drive unavailable")
                        .font(Theme.monoXSmall)
                        .foregroundStyle(Theme.text)

                    Text("Files: \(store.syncSummary.totalFiles)")
                        .font(Theme.monoXSmall)
                        .foregroundStyle(Theme.textDim)

                    if !store.syncSummary.statusText.isEmpty {
                        Text("Status: \(store.syncSummary.statusText)")
                            .font(Theme.monoXSmall)
                            .foregroundStyle(Theme.textDim)
                    }
                }

                Divider().background(Theme.border)

                // API Keys
                VStack(alignment: .leading, spacing: 4) {
                    Text("OpenRouter API Key")
                        .font(Theme.monoXSmall)
                        .foregroundStyle(Theme.textDim)

                    HStack(spacing: 6) {
                        SecureField("sk-or-...", text: $store.openRouterAPIKey.sending(\.updateAPIKey))
                            .textFieldStyle(.plain)
                            .font(Theme.monoSmall)
                            .foregroundStyle(Theme.text)
                            .padding(6)
                            .background(Theme.backgroundTertiary)

                        if !store.openRouterAPIKey.isEmpty {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .font(.system(size: 12))
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("OpenAI API Key")
                        .font(Theme.monoXSmall)
                        .foregroundStyle(Theme.textDim)

                    HStack(spacing: 6) {
                        SecureField("sk-...", text: $store.openAIAPIKey.sending(\.updateOpenAIAPIKey))
                            .textFieldStyle(.plain)
                            .font(Theme.monoSmall)
                            .foregroundStyle(Theme.text)
                            .padding(6)
                            .background(Theme.backgroundTertiary)

                        if !store.openAIAPIKey.isEmpty {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .font(.system(size: 12))
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Anthropic API Key")
                        .font(Theme.monoXSmall)
                        .foregroundStyle(Theme.textDim)

                    HStack(spacing: 6) {
                        SecureField("sk-ant-...", text: $store.anthropicAPIKey.sending(\.updateAnthropicAPIKey))
                            .textFieldStyle(.plain)
                            .font(Theme.monoSmall)
                            .foregroundStyle(Theme.text)
                            .padding(6)
                            .background(Theme.backgroundTertiary)

                        if !store.anthropicAPIKey.isEmpty {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .font(.system(size: 12))
                        }
                    }
                }

                // Model Picker
                VStack(alignment: .leading, spacing: 4) {
                    Text("Model")
                        .font(Theme.monoXSmall)
                        .foregroundStyle(Theme.textDim)

                    Picker("", selection: $store.selectedModel.sending(\.updateModel)) {
                        ForEach(store.availableModels, id: \.self) { model in
                            Text(model.split(separator: "/").last.map(String.init) ?? model)
                                .tag(model)
                        }
                        if !store.availableModels.contains(store.selectedModel) {
                            Text(store.selectedModel.split(separator: "/").last.map(String.init) ?? store.selectedModel)
                                .tag(store.selectedModel)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .font(Theme.monoSmall)
                }

                // Custom Model
                VStack(alignment: .leading, spacing: 4) {
                    Text("Custom Model")
                        .font(Theme.monoXSmall)
                        .foregroundStyle(Theme.textDim)

                    HStack(spacing: 4) {
                        TextField("provider/model-name", text: $customModelInput)
                            .textFieldStyle(.plain)
                            .font(Theme.monoSmall)
                            .foregroundStyle(Theme.text)
                            .padding(6)
                            .background(Theme.backgroundTertiary)
                            .onSubmit { addCustomModel() }

                        Button { Haptics.play(.light); addCustomModel() } label: {
                            Image(systemName: "plus")
                                .foregroundStyle(Theme.accent)
                        }
                        .buttonStyle(.plain)
                        .disabled(customModelInput.trimmingCharacters(in: .whitespaces).isEmpty)
                    }

                    ForEach(store.customModelList, id: \.self) { model in
                        HStack(spacing: 6) {
                            Text(model)
                                .font(Theme.monoXSmall)
                                .foregroundStyle(Theme.text)
                                .lineLimit(1)

                            Spacer()

                            Button {
                                Haptics.play(.light)
                                store.send(.removeCustomModel(model))
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 9))
                                    .foregroundStyle(Theme.textDim)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Divider().background(Theme.border)

                // Community
                VStack(alignment: .leading, spacing: 4) {
                    Text("Community")
                        .font(Theme.monoXSmall)
                        .foregroundStyle(Theme.textDim)

                    HStack(spacing: 8) {
                        Link(destination: URL(string: "https://github.com/polka-computer/Hashy")!) {
                            Label("GitHub", systemImage: "chevron.left.forwardslash.chevron.right")
                                .font(Theme.monoXSmall)
                                .foregroundStyle(Theme.accent)
                        }
                        Link(destination: URL(string: "https://discord.gg/zwpnkxETJ3")!) {
                            Label("Discord", systemImage: "bubble.left.and.bubble.right")
                                .font(Theme.monoXSmall)
                                .foregroundStyle(Theme.accent)
                        }
                    }
                }

                Divider().background(Theme.border)

                #if os(iOS)
                // macOS App Banner
                Link(destination: URL(string: "https://hashy.ink")!) {
                    HStack(spacing: 10) {
                        Text("💻")
                            .font(.title2)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Hashy for macOS")
                                .font(Theme.monoBold)
                                .foregroundStyle(Theme.text)
                            Text("Get the full desktop experience")
                                .font(Theme.monoXSmall)
                                .foregroundStyle(Theme.textDim)
                        }
                        Spacer()
                        Text("Get →")
                            .font(Theme.monoSmall)
                            .foregroundStyle(Theme.accent)
                    }
                    .padding(10)
                    .background(Theme.backgroundTertiary)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Theme.accent.opacity(0.3), lineWidth: 1)
                    )
                }
                #endif

                #if os(macOS)
                Divider().background(Theme.border)

                // iOS App Banner
                Link(destination: URL(string: "https://apps.apple.com/us/app/hashy-markdown-notes/id6759118041")!) {
                    HStack(spacing: 10) {
                        Text("📱")
                            .font(.title2)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Hashy for iOS")
                                .font(Theme.monoBold)
                                .foregroundStyle(Theme.text)
                            Text("Sync your notes on iPhone & iPad")
                                .font(Theme.monoXSmall)
                                .foregroundStyle(Theme.textDim)
                        }
                        Spacer()
                        Text("Get →")
                            .font(Theme.monoSmall)
                            .foregroundStyle(Theme.accent)
                    }
                    .padding(10)
                    .background(Theme.backgroundTertiary)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Theme.accent.opacity(0.3), lineWidth: 1)
                    )
                }

                Divider().background(Theme.border)

                // Keyboard Shortcuts
                KeyboardShortcutsSection()
                #endif
            }
            .padding(16)
        }
        #if os(macOS)
        .frame(width: 420)
        #else
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .sheet(isPresented: $showFolderPicker) {
            FolderPickerView { url in
                store.send(.vaultFolderChosen(url))
                showFolderPicker = false
            }
        }
        #endif
        .background(Theme.backgroundSecondary)
    }

    private func addCustomModel() {
        let trimmed = customModelInput.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        store.send(.addCustomModel(trimmed))
        customModelInput = ""
    }
}

private struct KeyboardShortcutsSection: View {
    private let shortcuts: [(key: String, label: String)] = [
        ("⌘N", "New Note"),
        ("⌘S", "Save"),
        ("⇧⌘⌫", "Delete Note"),
        ("⌘K", "Find Note"),
        ("⌘F", "Find in Note"),
        ("⌥↑", "Previous Note"),
        ("⌥↓", "Next Note"),
        ("⌘[", "Back"),
        ("⌘]", "Forward"),
        ("⌘L", "AI Chat"),
        ("⌘\\", "Toggle Sidebar"),
        ("⇧⌘F", "Zen Mode"),
        ("⌘B", "Bold"),
        ("⌘I", "Italic"),
        ("⌘↩", "Toggle Todo"),
        ("⇥", "Indent"),
        ("⇧⇥", "Outdent"),
        ("↩", "Open / Create Note"),
        ("⌘↩", "Force Create Note"),
        ("⌘,", "Settings"),
    ]

    private var leftColumn: [(key: String, label: String)] {
        Array(shortcuts.prefix(half))
    }

    private var rightColumn: [(key: String, label: String)] {
        Array(shortcuts.suffix(from: half))
    }

    private var half: Int { (shortcuts.count + 1) / 2 }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Keyboard Shortcuts")
                .font(Theme.monoXSmall)
                .foregroundStyle(Theme.textDim)

            HStack(alignment: .top, spacing: 16) {
                shortcutColumn(leftColumn)
                shortcutColumn(rightColumn)
            }
        }
    }

    private func shortcutColumn(_ items: [(key: String, label: String)]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, shortcut in
                HStack(spacing: 8) {
                    Text(shortcut.key)
                        .font(Theme.monoXSmall)
                        .foregroundStyle(Theme.accent)
                        .frame(width: 40, alignment: .trailing)
                    Text(shortcut.label)
                        .font(Theme.monoXSmall)
                        .foregroundStyle(Theme.textDim)
                }
            }
        }
    }
}
