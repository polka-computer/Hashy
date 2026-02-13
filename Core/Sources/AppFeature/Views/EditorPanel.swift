import ComposableArchitecture
import MarkdownStorage
import HashyEditor
import SwiftUI

/// Editor panel wrapping HashyEditorView with a header bar and auto-save.
/// Supports single-file and multi-pane (split) modes.
struct EditorPanel: View {
    @Bindable var store: StoreOf<AppFeature>
    @State private var localRenameText: String = ""
    @FocusState private var isRenameFocused: Bool
    #if os(macOS)
    @State private var showIconPicker: Bool = false
    #endif
    @State private var showTagPopover: Bool = false
    @State private var newTagText: String = ""

    var body: some View {
        Group {
            if let file = store.selectedFile, !file.isDirectory {
                singleFileView(file: file)
            } else {
                emptyState
            }
        }
        .background(Theme.background)
    }

    // MARK: - Single File View

    @ViewBuilder
    private func singleFileView(file: MarkdownFile) -> some View {
        VStack(spacing: 0) {
            #if os(macOS)
            // Header bar — title row
            HStack(spacing: 8) {
                // Emoji icon button
                Button {
                    Haptics.play(.light)
                    showIconPicker = true
                } label: {
                    if let icon = store.displayIcon, !icon.isEmpty {
                        Text(icon)
                            .font(.system(size: 16))
                    } else {
                        Image(systemName: "doc.text")
                            .foregroundStyle(Theme.textDim)
                            .font(.system(size: 13))
                    }
                }
                .buttonStyle(.plain)
                .help("Change icon")
                .popover(isPresented: $showIconPicker) {
                    EmojiPickerView { emoji in
                        Haptics.play(.light)
                        store.send(.updateFileIcon(emoji))
                        showIconPicker = false
                    }
                }

                // Title (double-click to rename)
                if store.renamingFileURL == file.url {
                    TextField("Title", text: $localRenameText)
                        .textFieldStyle(.plain)
                        .font(Theme.mono)
                        .foregroundStyle(Theme.text)
                        .frame(maxWidth: 200)
                        .focused($isRenameFocused)
                        .onSubmit {
                            store.send(.submitRename(localRenameText))
                        }
                        #if os(macOS)
                        .onExitCommand {
                            store.send(.cancelRename)
                        }
                        #endif
                        .onAppear {
                            isRenameFocused = true
                        }
                        .onChange(of: isRenameFocused) { _, focused in
                            if !focused {
                                store.send(.submitRename(localRenameText))
                            }
                        }
                } else {
                    Text(store.displayTitle)
                        .font(Theme.mono)
                        .foregroundStyle(Theme.text)
                        .lineLimit(1)
                        .onTapGesture(count: 2) {
                            localRenameText = store.displayTitle
                            store.send(.startRenameFile(file))
                        }
                }

                if store.hasUnsavedChanges {
                    Circle()
                        .fill(Theme.accent)
                        .frame(width: 6, height: 6)
                }

                Spacer()

                if !file.isDownloaded {
                    Image(systemName: "icloud.and.arrow.down")
                        .foregroundStyle(Theme.textDim)
                        .font(.system(size: 11))
                }

                settingsButton

                #if os(macOS)
                Button { Haptics.play(.light); store.send(.toggleChat) } label: {
                    Image(systemName: store.isChatVisible ? "bubble.left.and.bubble.right.fill" : "bubble.left.and.bubble.right")
                        .foregroundStyle(store.isChatVisible ? Theme.accent : Theme.textDim)
                        .font(.system(size: 12))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background(Theme.backgroundTertiary)
                }
                .buttonStyle(.plain)
                .help("Toggle AI Chat")
                #endif

                Button { Haptics.play(.warning); store.send(.deleteFile(file)) } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(.red.opacity(0.7))
                        .font(.system(size: 11))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background(Theme.backgroundTertiary)
                }
                .buttonStyle(.plain)
                .help("Delete note")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(Theme.backgroundSecondary)
            #endif

            // Tag row — below the title
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 5) {
                    ForEach(store.displayTags, id: \.self) { tag in
                        tagPill(tag)
                    }

                    addTagButton
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
            }
            .background(Theme.backgroundSecondary)

            Divider().background(Theme.border)

            // Editor — fill remaining space without growing the parent
            HashyEditorView(text: $store.editorContent.sending(\.updateEditorContent))
                .completionProvider { query in
                    let q = query.lowercased()
                    return store.files
                        .filter { !$0.isDirectory }
                        .filter { q.isEmpty || $0.title.lowercased().contains(q) || $0.name.lowercased().contains(q) }
                        .prefix(8)
                        .map { file in
                            HashyCompletionResult(
                                id: file.name,
                                title: file.title,
                                icon: "doc.text",
                                typeName: "Note"
                            )
                        }
                }
                .onLinkClicked { objectId in
                    if let file = store.files.first(where: { $0.name == objectId }) {
                        store.send(.selectFile(file))
                    }
                }
                .onTextChange { _ in
                    debounceAutoSave()
                }
                .imageBaseURL(CloudContainerProvider.documentsDirectory())
                .focusTrigger(store.editorFocusTrigger)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 0) {
            #if os(macOS)
            HStack {
                Spacer()
                settingsButton
                Button { Haptics.play(.light); store.send(.toggleChat) } label: {
                    Image(systemName: store.isChatVisible ? "bubble.left.and.bubble.right.fill" : "bubble.left.and.bubble.right")
                        .foregroundStyle(store.isChatVisible ? Theme.accent : Theme.textDim)
                        .font(.system(size: 12))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background(Theme.backgroundTertiary)
                }
                .buttonStyle(.plain)
                .help("Toggle AI Chat")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Theme.backgroundSecondary)

            Divider().background(Theme.border)
            #endif

            Spacer()
            VStack(spacing: 12) {
                Image(systemName: "doc.text")
                    .font(.system(size: 40))
                    .foregroundStyle(Theme.textMuted)

                Text("Search or create a note below")
                    .font(Theme.mono)
                    .foregroundStyle(Theme.textMuted)
            }
            Spacer()
        }
    }

    private var settingsButton: some View {
        Button { Haptics.play(.light); store.send(.setSettingsVisible(true)) } label: {
            Image(systemName: "gearshape")
                .foregroundStyle(Theme.textDim)
                .font(.system(size: 12))
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background(Theme.backgroundTertiary)
        }
        .buttonStyle(.plain)
        .help("Settings")
        #if os(macOS)
        .popover(isPresented: $store.isSettingsVisible.sending(\.setSettingsVisible)) {
            SettingsView(store: store)
        }
        #endif
    }

    // MARK: - Tag Helpers

    private func tagPill(_ tag: String) -> some View {
        HStack(spacing: 3) {
            Text(tag)
                .font(Theme.monoXSmall)
                .foregroundStyle(Theme.accent)
            Button {
                Haptics.play(.light)
                store.send(.removeTag(tag))
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(Theme.accent.opacity(0.6))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Theme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
    }

    private var addTagButton: some View {
        Button {
            Haptics.play(.light)
            newTagText = ""
            showTagPopover = true
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Theme.textDim)
                .padding(4)
        }
        .buttonStyle(.plain)
        .help("Add tag")
        #if os(macOS)
        .popover(isPresented: $showTagPopover) {
            TagEditorPopover(
                text: $newTagText,
                allTags: store.allTags,
                existingTags: store.displayTags
            ) { tag in
                Haptics.play(.success)
                store.send(.addTag(tag))
                newTagText = ""
                showTagPopover = false
            }
        }
        #else
        .sheet(isPresented: $showTagPopover) {
            TagEditorSheet(
                text: $newTagText,
                allTags: store.allTags,
                existingTags: store.displayTags,
                onAdd: { tag in
                    Haptics.play(.success)
                    store.send(.addTag(tag))
                    newTagText = ""
                },
                onDismiss: { showTagPopover = false }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationBackground(Theme.backgroundSecondary)
        }
        #endif
    }

    // MARK: - Auto-save

    @State private var saveTask: Task<Void, Never>?

    private func debounceAutoSave() {
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            store.send(.saveCurrentFile)
        }
    }
}

// MARK: - Tag helpers (shared logic)

private func tagSuggestions(query: String, allTags: [String], existingTags: [String]) -> [String] {
    let available = allTags.filter { tag in
        !existingTags.contains { $0.lowercased() == tag.lowercased() }
    }
    if query.isEmpty { return available }
    let q = query.lowercased()
    return available.filter { $0.lowercased().contains(q) }
}

private func tagIsNew(_ query: String, allTags: [String]) -> Bool {
    guard !query.isEmpty else { return false }
    let q = query.lowercased()
    return !allTags.contains { $0.lowercased() == q }
}

// MARK: - Tag Editor Popover (macOS)

private struct TagEditorPopover: View {
    @Binding var text: String
    let allTags: [String]
    let existingTags: [String]
    let onAdd: (String) -> Void
    @FocusState private var isFocused: Bool

    private var trimmed: String { text.trimmingCharacters(in: .whitespaces) }
    private var suggestions: [String] { tagSuggestions(query: trimmed, allTags: allTags, existingTags: existingTags) }
    private var showCreateOption: Bool { tagIsNew(trimmed, allTags: allTags) }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textMuted)

                TextField("Search or create tag…", text: $text)
                    .textFieldStyle(.plain)
                    .font(Theme.monoSmall)
                    .foregroundStyle(Theme.text)
                    .focused($isFocused)
                    .onSubmit {
                        guard !trimmed.isEmpty else { return }
                        onAdd(trimmed)
                    }

                if !text.isEmpty {
                    Button { text = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.textMuted)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Theme.backgroundTertiary, in: RoundedRectangle(cornerRadius: 6, style: .continuous))

            ScrollView {
                VStack(alignment: .leading, spacing: 1) {
                    if showCreateOption {
                        Button { onAdd(trimmed) } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 11))
                                    .foregroundStyle(Theme.accent)
                                Text("Create \"\(trimmed)\"")
                                    .font(Theme.monoSmall)
                                    .foregroundStyle(Theme.accent)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(Theme.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }

                    ForEach(suggestions, id: \.self) { tag in
                        Button { onAdd(tag) } label: {
                            HStack(spacing: 6) {
                                Text("#")
                                    .font(Theme.monoXSmall)
                                    .foregroundStyle(Theme.textMuted)
                                Text(tag)
                                    .font(Theme.monoSmall)
                                    .foregroundStyle(Theme.text)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                        }
                        .buttonStyle(.plain)
                    }

                    if suggestions.isEmpty && !showCreateOption {
                        Text("No tags yet")
                            .font(Theme.monoXSmall)
                            .foregroundStyle(Theme.textMuted)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                }
            }
            .frame(maxHeight: 180)
        }
        .padding(8)
        .frame(width: 200)
        .background(Theme.backgroundSecondary)
        .onAppear { isFocused = true }
    }
}

// MARK: - Tag Editor Sheet (iOS)

#if os(iOS)
private struct TagEditorSheet: View {
    @Binding var text: String
    let allTags: [String]
    let existingTags: [String]
    let onAdd: (String) -> Void
    let onDismiss: () -> Void
    @FocusState private var isFocused: Bool

    private var trimmed: String { text.trimmingCharacters(in: .whitespaces) }
    private var suggestions: [String] { tagSuggestions(query: trimmed, allTags: allTags, existingTags: existingTags) }
    private var showCreateOption: Bool { tagIsNew(trimmed, allTags: allTags) }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Theme.textMuted)

                    TextField("Search or create tag…", text: $text)
                        .font(.system(size: 16))
                        .foregroundStyle(Theme.text)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .focused($isFocused)
                        .submitLabel(.done)
                        .onSubmit {
                            guard !trimmed.isEmpty else { return }
                            onAdd(trimmed)
                        }

                    if !text.isEmpty {
                        Button { text = "" } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 17))
                                .foregroundStyle(Theme.textMuted)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .frame(height: 48)
                .background(Theme.backgroundTertiary, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 12)

                Divider().foregroundStyle(Theme.border)

                // Tag list
                List {
                    if showCreateOption {
                        Button { onAdd(trimmed) } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundStyle(Theme.accent)
                                Text("Create \"\(trimmed)\"")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(Theme.accent)
                            }
                        }
                        .listRowBackground(Theme.accent.opacity(0.08))
                        .listRowSeparatorTint(Theme.border)
                    }

                    ForEach(suggestions, id: \.self) { tag in
                        Button { onAdd(tag) } label: {
                            HStack(spacing: 10) {
                                Text("#")
                                    .font(.system(size: 15, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(Theme.accent)
                                    .frame(width: 22)
                                Text(tag)
                                    .font(.system(size: 16))
                                    .foregroundStyle(Theme.text)
                                Spacer()
                            }
                        }
                        .listRowBackground(Color.clear)
                        .listRowSeparatorTint(Theme.border)
                    }

                    if suggestions.isEmpty && !showCreateOption {
                        HStack {
                            Spacer()
                            Text("No tags yet — type to create one")
                                .font(.system(size: 14))
                                .foregroundStyle(Theme.textMuted)
                            Spacer()
                        }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .padding(.vertical, 20)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
            .background(Theme.backgroundSecondary)
            .navigationTitle("Add Tag")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { onDismiss() }
                        .foregroundStyle(Theme.accent)
                }
            }
        }
        .onAppear { isFocused = true }
    }
}
#endif
