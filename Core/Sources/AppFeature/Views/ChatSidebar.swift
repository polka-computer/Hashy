import AIFeature
import ComposableArchitecture
import MarkdownStorage
import SwiftUI

/// AI chat sidebar with message UI, powered by OpenRouter.
struct ChatSidebar: View {
    @Bindable var store: StoreOf<AppFeature>
    var showsHeader: Bool = true
    var showsCloseButton: Bool = true
    var showsInputBar: Bool = true
    var externalBottomInset: CGFloat = 0
    @State private var mentionSelectionIndex: Int = 0
    @FocusState private var isChatInputFocused: Bool

    private var isMentionDropdownVisible: Bool {
        store.chatMentionQuery != nil && !store.chatMentionSuggestions.isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            if showsHeader {
                // Header
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(Theme.accent)
                        .font(.system(size: 12))

                    Text("AI Chat")
                        .font(Theme.monoBold)
                        .foregroundStyle(Theme.text)

                    Spacer()

                    if !store.chatMessages.isEmpty {
                        Button { Haptics.play(.warning); store.send(.clearChat) } label: {
                            Image(systemName: "trash")
                                .foregroundStyle(Theme.textDim)
                                .font(.system(size: 11))
                        }
                        .buttonStyle(.plain)
                        .help("Clear chat")
                    }

                    if showsCloseButton {
                        Button { Haptics.play(.light); store.send(.toggleChat) } label: {
                            Image(systemName: "xmark")
                                .foregroundStyle(Theme.textDim)
                                .font(.system(size: 11))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)

                Divider().background(Theme.border)
            }

            // Messages or empty state
            if store.chatMessages.isEmpty {
                Spacer()
                VStack(spacing: 14) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 24))
                        .foregroundStyle(Theme.accent)

                    Text("Try something like...")
                        .font(Theme.mono)
                        .foregroundStyle(Theme.textMuted)

                    VStack(alignment: .leading, spacing: 6) {
                        ExamplePrompt("Add emojis to all notes missing one") {
                            store.send(.sendChatMessage("Add emojis to all notes missing one"))
                        }
                        ExamplePrompt("Tag all my untagged notes") {
                            store.send(.sendChatMessage("Tag all my untagged notes"))
                        }
                        ExamplePrompt("Create a note with movie suggestions") {
                            store.send(.sendChatMessage("Create a note with movie suggestions"))
                        }
                        ExamplePrompt("Summarize my current note") {
                            store.send(.sendChatMessage("Summarize my current note"))
                        }
                        ExamplePrompt("Find notes about travel") {
                            store.send(.sendChatMessage("Find notes about travel"))
                        }
                        ExamplePrompt("Rename my note to something better") {
                            store.send(.sendChatMessage("Rename my note to something better"))
                        }
                        ExamplePrompt("Delete all empty notes") {
                            store.send(.sendChatMessage("Delete all empty notes"))
                        }
                    }
                }
                .padding(.horizontal, 16)
                Spacer()
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(store.chatMessages) { message in
                                ChatBubble(message: message)
                            }

                            if store.isChatLoading {
                                HStack {
                                    ProgressView()
                                        .scaleEffect(0.7)
                                    Text("Thinking...")
                                        .font(Theme.monoXSmall)
                                        .foregroundStyle(Theme.textMuted)
                                    Spacer()
                                }
                                .padding(.horizontal, 12)
                                .id("loading")
                            }
                        }
                        .padding(.vertical, 12)
                    }
                    .safeAreaInset(edge: .bottom, spacing: 0) {
                        if !showsInputBar {
                            Color.clear
                                .frame(height: max(0, externalBottomInset))
                        }
                    }
                    .scrollDismissesKeyboard(.never)
                    .onChange(of: store.chatMessages.count) { _, _ in
                        withAnimation {
                            if let lastId = store.chatMessages.last?.id {
                                proxy.scrollTo(lastId, anchor: .bottom)
                            }
                        }
                    }
                }
            }

            // Error banner
            if let error = store.chatError {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 10))
                    Text(error)
                        .font(Theme.monoXSmall)
                        .lineLimit(2)
                }
                .foregroundStyle(.red)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.red.opacity(0.1))
            }

            if showsInputBar {
                Divider().background(Theme.border)

                // @mention autocomplete
                if isMentionDropdownVisible {
                    let suggestions = Array(store.chatMentionSuggestions.prefix(6))
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(Array(suggestions.enumerated()), id: \.element.id) { index, file in
                                Button {
                                    store.send(.insertChatMention(file))
                                    mentionSelectionIndex = 0
                                } label: {
                                    HStack(spacing: 6) {
                                        if let icon = file.icon, !icon.isEmpty {
                                            Text(icon).font(.system(size: 12))
                                        } else {
                                            Image(systemName: "doc.text")
                                                .font(.system(size: 10))
                                                .foregroundStyle(Theme.textDim)
                                        }
                                        Text(file.title)
                                            .font(Theme.monoSmall)
                                            .foregroundStyle(Theme.text)
                                            .lineLimit(1)
                                        Spacer()
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(index == mentionSelectionIndex ? Theme.selection : Color.clear)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .frame(maxHeight: 160)
                    .background(Theme.backgroundTertiary)
                    .overlay(alignment: .bottom) {
                        Divider().background(Theme.border)
                    }
                    .onChange(of: store.chatMentionSuggestions) { _, _ in
                        mentionSelectionIndex = 0
                    }
                }

                // Input area
                VStack(spacing: 6) {
                    // Model picker
                    HStack(spacing: 0) {
                        Menu {
                            ForEach(AppFeature.availableModels, id: \.self) { model in
                                Button {
                                    store.send(.updateModel(model))
                                } label: {
                                    if model == store.selectedModel {
                                        Label(
                                            model.split(separator: "/").last.map(String.init) ?? model,
                                            systemImage: "checkmark"
                                        )
                                    } else {
                                        Text(model.split(separator: "/").last.map(String.init) ?? model)
                                    }
                                }
                            }

                            if !store.customModelList.isEmpty {
                                Divider()
                                ForEach(store.customModelList, id: \.self) { model in
                                    Button {
                                        store.send(.updateModel(model))
                                    } label: {
                                        if model == store.selectedModel {
                                            Label(
                                                model.split(separator: "/").last.map(String.init) ?? model,
                                                systemImage: "checkmark"
                                            )
                                        } else {
                                            Text(model.split(separator: "/").last.map(String.init) ?? model)
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 3) {
                                Text(store.selectedModel.split(separator: "/").last.map(String.init) ?? store.selectedModel)
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 7))
                            }
                            .font(Theme.monoXSmall)
                            .foregroundStyle(Theme.textDim)
                        }
                        #if os(macOS)
                        .menuStyle(.borderlessButton)
                        .menuIndicator(.hidden)
                        #endif
                        .fixedSize()

                        Spacer()
                    }

                    HStack(alignment: .bottom, spacing: 8) {
                        ZStack(alignment: .topLeading) {
                            if store.chatInput.isEmpty {
                                Text("Ask AI...")
                                    .font(Theme.monoSmall)
                                    .foregroundStyle(Theme.textMuted)
                                    .padding(.top, 1)
                                    .allowsHitTesting(false)
                            }

                            TextEditor(text: $store.chatInput.sending(\.updateChatInput))
                                .font(Theme.monoSmall)
                                .foregroundStyle(Theme.text)
                                .scrollContentBackground(.hidden)
                                .focused($isChatInputFocused)
                                .frame(minHeight: 20, maxHeight: 180)
                                .fixedSize(horizontal: false, vertical: true)
                                #if os(macOS)
                                .onKeyPress(.return, phases: .down) { keyPress in
                                    if isMentionDropdownVisible {
                                        let suggestions = Array(store.chatMentionSuggestions.prefix(6))
                                        let idx = min(mentionSelectionIndex, suggestions.count - 1)
                                        if idx >= 0 {
                                            store.send(.insertChatMention(suggestions[idx]))
                                            mentionSelectionIndex = 0
                                        }
                                        return .handled
                                    }
                                    if keyPress.modifiers.contains(.shift) {
                                        return .ignored
                                    }
                                    store.send(.sendChatMessage(store.chatInput))
                                    return .handled
                                }
                                .onKeyPress(.upArrow) {
                                    if isMentionDropdownVisible {
                                        mentionSelectionIndex = max(mentionSelectionIndex - 1, 0)
                                        return .handled
                                    }
                                    return .ignored
                                }
                                .onKeyPress(.downArrow) {
                                    if isMentionDropdownVisible {
                                        let count = min(store.chatMentionSuggestions.count, 6)
                                        mentionSelectionIndex = min(mentionSelectionIndex + 1, count - 1)
                                        return .handled
                                    }
                                    return .ignored
                                }
                                .onKeyPress(.escape) {
                                    if isMentionDropdownVisible {
                                        store.send(.updateChatMentionQuery(nil))
                                        mentionSelectionIndex = 0
                                        return .handled
                                    }
                                    return .ignored
                                }
                                #endif
                        }

                        Button {
                            Haptics.play(.light)
                            store.send(.sendChatMessage(store.chatInput))
                        } label: {
                            Image(systemName: "arrow.up.circle.fill")
                                .foregroundStyle(store.chatInput.trimmingCharacters(in: .whitespaces).isEmpty
                                    ? Theme.textMuted : Theme.accent)
                        }
                        .buttonStyle(.plain)
                        .disabled(store.chatInput.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Theme.backgroundTertiary)
            }
        }
        .background(Theme.backgroundSecondary)
        .onAppear {
            if showsInputBar {
                isChatInputFocused = true
            }
        }
        .onChange(of: store.chatFocusTrigger) { _, _ in
            if showsInputBar {
                isChatInputFocused = true
            }
        }
    }
}

// MARK: - Example Prompt

private struct ExamplePrompt: View {
    let text: String
    let action: () -> Void

    init(_ text: String, action: @escaping () -> Void) {
        self.text = text
        self.action = action
    }

    var body: some View {
        Button { Haptics.play(.light); action() } label: {
            HStack(spacing: 6) {
                Image(systemName: "arrow.right")
                    .font(.system(size: 8))
                    .foregroundStyle(Theme.accent)
                Text(text)
                    .font(Theme.monoXSmall)
                    .foregroundStyle(Theme.textDim)
                    .lineLimit(1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Chat Bubble

private struct ChatBubble: View {
    let message: ChatMessage

    var body: some View {
        if message.role == .tool {
            // Tool call log — compact inline
            HStack(spacing: 4) {
                Text(message.content)
                    .font(Theme.monoXSmall)
                    .foregroundStyle(Theme.textDim)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 1)
        } else {
            HStack {
                if message.role == .user { Spacer(minLength: 40) }

                VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                    Text(message.content)
                        .font(Theme.monoSmall)
                        .foregroundStyle(Theme.text)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            message.role == .user
                                ? Theme.accent.opacity(0.15)
                                : Theme.backgroundTertiary
                        )

                    Text(RelativeTime.string(from: message.timestamp))
                        .font(Theme.monoXSmall)
                        .foregroundStyle(Theme.textMuted)
                }

                if message.role == .assistant { Spacer(minLength: 40) }
            }
            .padding(.horizontal, 12)
        }
    }
}
