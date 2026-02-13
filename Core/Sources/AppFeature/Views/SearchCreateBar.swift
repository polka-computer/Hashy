import ComposableArchitecture
import SwiftUI

/// Bottom bar for searching notes and creating new ones (nvALT-style).
struct SearchCreateBar: View {
    @Bindable var store: StoreOf<AppFeature>
    @FocusState private var isFocused: Bool
    @State private var tagSelectionIndex: Int = 0

    private var isTagDropdownVisible: Bool {
        store.searchTagQuery != nil && !store.searchTagSuggestions.isEmpty
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Theme.textMuted)
                .font(.system(size: 13))

            TextField("Search or create note...", text: $store.searchText.sending(\.updateSearchText))
                .textFieldStyle(.plain)
                .font(Theme.monoSmall)
                .foregroundStyle(Theme.text)
                .focused($isFocused)
            #if os(macOS)
                .onKeyPress(.return, phases: .down) { keyPress in
                    if isTagDropdownVisible {
                        let suggestions = Array(store.searchTagSuggestions.prefix(8))
                        let idx = min(tagSelectionIndex, suggestions.count - 1)
                        if idx >= 0 {
                            store.send(.insertSearchTag(suggestions[idx]))
                            tagSelectionIndex = 0
                        }
                        return .handled
                    }
                    if keyPress.modifiers.contains(.command) {
                        store.send(.createNoteFromSearch)
                    } else {
                        store.send(.submitSearch)
                    }
                    return .handled
                }
                .onKeyPress(.upArrow) {
                    if isTagDropdownVisible {
                        tagSelectionIndex = max(tagSelectionIndex - 1, 0)
                        return .handled
                    }
                    store.send(.selectPreviousFile)
                    return .handled
                }
                .onKeyPress(.downArrow) {
                    if isTagDropdownVisible {
                        let count = min(store.searchTagSuggestions.count, 8)
                        tagSelectionIndex = min(tagSelectionIndex + 1, count - 1)
                        return .handled
                    }
                    store.send(.selectNextFile)
                    return .handled
                }
                .onKeyPress(.escape) {
                    if isTagDropdownVisible {
                        store.send(.updateSearchTagQuery(nil))
                        tagSelectionIndex = 0
                        return .handled
                    }
                    store.send(.clearSearch)
                    isFocused = false
                    return .handled
                }
            #else
                .onSubmit {
                    store.send(.submitSearch)
                }
            #endif

            if !store.searchText.isEmpty {
                if store.filteredFiles.isEmpty {
                    Text("+ create")
                        .font(Theme.monoXSmall)
                        .foregroundStyle(Theme.accent)
                } else if !store.searchMatchesExistingFile {
                    Text("\(store.filteredFiles.count) found")
                        .font(Theme.monoXSmall)
                        .foregroundStyle(Theme.textMuted)
                }

                Button {
                    Haptics.play(.light)
                    store.send(.clearSearch)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Theme.textMuted)
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .fixedSize(horizontal: false, vertical: true)
        .background(Theme.backgroundSecondary)
        .overlay(alignment: .top) {
            Divider().background(Theme.border)
        }
        .overlay(alignment: .bottomLeading) {
            if isTagDropdownVisible {
                let suggestions = Array(store.searchTagSuggestions.prefix(8))
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(suggestions.enumerated()), id: \.element) { index, tag in
                        Button {
                            Haptics.play(.light)
                            store.send(.insertSearchTag(tag))
                            tagSelectionIndex = 0
                        } label: {
                            Text("#\(tag)")
                                .font(Theme.monoSmall)
                                .foregroundStyle(Theme.text)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(index == tagSelectionIndex ? Theme.selection : Color.clear)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(width: 200)
                .background(Theme.backgroundTertiary)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Theme.border, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .shadow(color: .black.opacity(0.2), radius: 8, y: -4)
                .offset(x: 24, y: -4)
                .allowsHitTesting(true)
            }
        }
        .onChange(of: store.searchTagSuggestions) { _, _ in
            tagSelectionIndex = 0
        }
        .onChange(of: store.searchFocusTrigger) { _, _ in
            isFocused = true
        }
    }
}
