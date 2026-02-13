import ComposableArchitecture
import MarkdownStorage
import SwiftUI

#if canImport(AppKit)
import AppKit
#endif

#if canImport(UIKit)
import UIKit
#endif

/// Root layout for iOS and macOS.
public struct HashyMainView: View {
    @Bindable var store: StoreOf<AppFeature>

    #if os(iOS)
    @State private var homeTab: MobileHomeTab = .search
    @State private var showEditor: Bool = false
    @State private var homeInputFocusTrigger: Int = 0
    @State private var iosRenameText: String = ""
    @State private var showIOSRenamePrompt: Bool = false
    @State private var showIconPicker: Bool = false
    #endif

    public init(store: StoreOf<AppFeature>) {
        self.store = store
    }

    public var body: some View {
        #if os(iOS)
        mobileBody
        #else
        desktopBody
        #endif
    }

    #if os(iOS)
    private var mobileBody: some View {
        VStack(spacing: 0) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // HOME — always in hierarchy
                    homeContent
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .allowsHitTesting(!showEditor)

                    // EDITOR — slides in/out from right
                    editorContent
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .offset(x: showEditor ? 0 : geometry.size.width)
                        .allowsHitTesting(showEditor)
                        .gesture(
                            DragGesture()
                                .onEnded { value in
                                    if value.translation.width > 100 && abs(value.translation.height) < 50 {
                                        closeEditor()
                                    }
                                }
                        )
                }
                .animation(.easeInOut(duration: 0.25), value: showEditor)
            }

            if !showEditor {
                MobileHomeInputBar(store: store, tab: homeTab, focusTrigger: homeInputFocusTrigger)
                    .padding(.horizontal, 12)
                    .padding(.top, 6)
                    .padding(.bottom, 8)
                    .background(
                        Theme.background.opacity(0.96)
                            .overlay(alignment: .top) {
                                Divider().background(Theme.border)
                            }
                    )
            }
        }
        .background(Theme.background)
        .onAppear {
            store.send(.onAppear)
            if store.selectedFileURL != nil {
                showEditor = true
                DispatchQueue.main.async { store.send(.focusEditor) }
            } else {
                homeTab = .search
                if !store.showVaultSetupPrompt {
                    homeInputFocusTrigger += 1
                }
            }
        }
        .onChange(of: store.editorFocusTrigger) { _, _ in
            guard !store.isSettingsVisible, store.selectedFileURL != nil else { return }
            showEditor = true
        }
        .onChange(of: store.searchFocusTrigger) { _, _ in
            homeTab = .search
            showEditor = false
            homeInputFocusTrigger += 1
        }
        .onChange(of: store.selectedFileURL) { _, url in
            if url == nil && showEditor {
                showEditor = false
            }
        }
        .onChange(of: homeTab) { _, tab in
            guard !showEditor, !store.isSettingsVisible else { return }
            if tab == .chat {
                store.send(.openChat)
            }
            homeInputFocusTrigger += 1
        }
        .onChange(of: store.isSettingsVisible) { _, isVisible in
            guard !isVisible else { return }
            if showEditor {
                DispatchQueue.main.async { store.send(.focusEditor) }
            } else {
                if homeTab == .chat {
                    store.send(.openChat)
                }
                homeInputFocusTrigger += 1
            }
        }
        .sheet(item: Binding(
            get: { store.activeConflict },
            set: { _ in store.send(.conflictResolved) }
        )) { conflict in
            ConflictResolutionSheet(conflict: conflict, store: store)
        }
        .sheet(isPresented: $store.isSettingsVisible.sending(\.setSettingsVisible)) {
            NavigationStack {
                SettingsView(store: store)
                    .navigationTitle("Settings")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") {
                                store.send(.setSettingsVisible(false))
                            }
                        }
                    }
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $store.showVaultSetupPrompt.sending(\.dismissVaultSetup)) {
            VaultSetupSheet(store: store)
        }
    }

    // MARK: - Home Content

    private var homeContent: some View {
        VStack(spacing: 0) {
            topTabs
            if homeTab == .search {
                MobileNoteListPane(
                    store: store,
                    onOpenNote: openNote,
                    bottomContentInset: 0
                )
            } else {
                ChatSidebar(
                    store: store,
                    showsHeader: false,
                    showsCloseButton: false,
                    showsInputBar: false,
                    externalBottomInset: 0
                )
            }
        }
    }

    // MARK: - Editor Content

    private var editorContent: some View {
        VStack(spacing: 0) {
            editorNavBar
            EditorPanel(store: store)
        }
        .alert("Rename Note", isPresented: $showIOSRenamePrompt) {
            TextField("Title", text: $iosRenameText)
            Button("Cancel", role: .cancel) {}
            Button("Save") {
                let trimmed = iosRenameText.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return }
                Haptics.play(.success)
                if let file = store.selectedFile {
                    store.send(.startRenameFile(file))
                }
                store.send(.submitRename(trimmed))
            }
        }
        .sheet(isPresented: $showIconPicker) {
            EmojiPickerView { emoji in
                Haptics.play(.selection)
                store.send(.updateFileIcon(emoji))
                showIconPicker = false
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationBackground(Theme.backgroundSecondary)
        }
    }

    // MARK: - Editor Nav Bar

    private var editorNavBar: some View {
        HStack(spacing: 10) {
            Button {
                closeEditor()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Notes")
                        .font(.system(size: 17))
                }
                .foregroundStyle(Theme.accent)
            }
            .buttonStyle(.plain)

            Spacer()

            HStack(spacing: 6) {
                Button {
                    Haptics.play(.light)
                    showIconPicker = true
                } label: {
                    if let icon = store.displayIcon, !icon.isEmpty {
                        Text(icon)
                            .font(.system(size: 18))
                    } else {
                        Image(systemName: "doc.text")
                            .foregroundStyle(Theme.textDim)
                            .font(.system(size: 14, weight: .semibold))
                    }
                }
                .buttonStyle(.plain)

                Text(store.displayTitle)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
                    .onTapGesture {
                        Haptics.play(.light)
                        iosRenameText = store.displayTitle
                        showIOSRenamePrompt = true
                    }

                if store.hasUnsavedChanges {
                    Circle()
                        .fill(Theme.accent)
                        .frame(width: 6, height: 6)
                }
            }

            Spacer()

            if let file = store.selectedFile {
                Button {
                    Haptics.play(.warning)
                    store.send(.deleteFile(file))
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(.red.opacity(0.85))
                        .font(.system(size: 14, weight: .semibold))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            Theme.background.opacity(0.96)
                .overlay(alignment: .bottom) {
                    Divider().background(Theme.border)
                }
        )
    }

    // MARK: - Navigation

    private func openNote(_ file: MarkdownFile) {
        Haptics.play(.selection)
        store.send(.selectFile(file))
        store.send(.focusEditor)
        showEditor = true
    }

    private func closeEditor() {
        Haptics.play(.light)
        showEditor = false
        homeInputFocusTrigger += 1
    }

    private var topTabs: some View {
        HStack(spacing: 10) {
            MobileTabButton(title: "Search", systemImage: "magnifyingglass", isSelected: homeTab == .search) {
                homeTab = .search
            }
            MobileTabButton(title: "Chat", systemImage: "sparkles", isSelected: homeTab == .chat) {
                homeTab = .chat
            }
            Spacer(minLength: 8)
            if homeTab == .chat {
                Button {
                    Haptics.play(.light)
                    store.send(.clearChat)
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "xmark.circle")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Clear")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(store.chatMessages.isEmpty ? Theme.textMuted : Theme.text)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Theme.backgroundTertiary)
                    )
                }
                .buttonStyle(.plain)
                .disabled(store.chatMessages.isEmpty)
                .accessibilityLabel("Clear chat")
            }
            Button {
                Haptics.play(.light)
                store.send(.setSettingsVisible(true))
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.text)
                    .frame(width: 34, height: 34)
                    .background(Theme.backgroundTertiary, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Settings")
        }
        .padding(.horizontal, 14)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(
            Theme.background.opacity(0.96)
                .overlay(alignment: .bottom) {
                    Divider().background(Theme.border)
                }
        )
    }

    #else
    private var desktopBody: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                if store.isSidebarVisible {
                    FileSidebar(store: store)
                        .frame(width: 260)

                    Divider()
                        .background(Theme.border)
                }

                EditorPanel(store: store)
                    .ignoresSafeArea(.container, edges: .top)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                if store.isChatVisible {
                    Divider()
                        .background(Theme.border)

                    ChatSidebar(store: store)
                        .ignoresSafeArea(.container, edges: .top)
                        .frame(width: 300)
                }
            }

            if !store.isZenMode {
                SearchCreateBar(store: store)
            }
        }
        .background(Theme.background)
        .frame(minWidth: 900, minHeight: 600)
        .onAppear {
            store.send(.onAppear)
            #if os(macOS)
            DispatchQueue.main.async {
                if let window = NSApplication.shared.windows.first {
                    window.titlebarAppearsTransparent = true
                    window.titlebarSeparatorStyle = .none
                    window.titleVisibility = .hidden
                    window.isMovableByWindowBackground = true

                    let screen = NSScreen.main?.visibleFrame ?? .zero
                    let size = NSSize(
                        width: min(1600, screen.width * 0.85),
                        height: min(1000, screen.height * 0.85)
                    )
                    let origin = NSPoint(
                        x: screen.midX - size.width / 2,
                        y: screen.midY - size.height / 2
                    )
                    window.setFrame(NSRect(origin: origin, size: size), display: true)
                }
            }
            #endif
        }
        .sheet(item: Binding(
            get: { store.activeConflict },
            set: { _ in store.send(.conflictResolved) }
        )) { conflict in
            ConflictResolutionSheet(conflict: conflict, store: store)
        }
    }
#endif
}

#if os(iOS)
private enum MobileHomeTab: Hashable {
    case search
    case chat
}

private struct MobileNoteListPane: View {
    @Bindable var store: StoreOf<AppFeature>
    let onOpenNote: (MarkdownFile) -> Void
    let bottomContentInset: CGFloat

    var body: some View {
        notesList
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .background(
            LinearGradient(
                colors: [Theme.background, Theme.backgroundSecondary],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
    }

    @ViewBuilder
    private var notesList: some View {
        if store.filteredFiles.isEmpty {
            ContentUnavailableView {
                Label("No notes found", systemImage: "doc.text")
            } description: {
                Text("Use the compose button to create a note from the current search text.")
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List {
                ForEach(store.filteredFiles) { file in
                    Button {
                        onOpenNote(file)
                    } label: {
                        MobileNoteRow(file: file, isSelected: store.selectedFileURL == file.url)
                    }
                    .buttonStyle(.plain)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 4, leading: 4, bottom: 4, trailing: 4))
                    .listRowBackground(Color.clear)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            Haptics.play(.warning)
                            store.send(.deleteFile(file))
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.never)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Color.clear
                    .frame(height: max(0, bottomContentInset))
            }
        }
    }
}

// MARK: - UIKit Color Constants

private enum ThemeUIKit {
    static let background = UIColor.black
    static let backgroundTertiary = UIColor(white: 0.05, alpha: 1.0)
    static let accent = UIColor(red: 0.32, green: 0.90, blue: 0.55, alpha: 1.0)
    static let text = UIColor(white: 0.92, alpha: 1.0)
    static let textMuted = UIColor(white: 0.35, alpha: 1.0)
    static let toolbarBackground = UIColor(white: 0.06, alpha: 0.95)
}

// MARK: - HomeChipToolbarView

private class HomeChipToolbarView: UIView {
    private let scrollView = UIScrollView()
    private let stack = UIStackView()

    var onToggleTag: ((MobileSearchTagStat) -> Void)?
    var onSelectModel: ((String) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = ThemeUIKit.toolbarBackground
        autoresizingMask = .flexibleWidth

        scrollView.showsHorizontalScrollIndicator = false
        scrollView.alwaysBounceHorizontal = true
        scrollView.keyboardDismissMode = .none
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(scrollView)

        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stack)

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            scrollView.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),
            stack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            stack.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func updateTagChips(tags: [MobileSearchTagStat], activeFilters: Set<String>) {
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for stat in tags {
            let isActive = activeFilters.contains(stat.normalizedTag)
            let button = makeTagChip(stat: stat, isActive: isActive)
            stack.addArrangedSubview(button)
        }
    }

    func updateModelChips(models: [String], selectedModel: String) {
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for model in models {
            let shortName = model.split(separator: "/").last.map(String.init) ?? model
            let isSelected = model == selectedModel
            let button = makeModelChip(model: model, shortName: shortName, isSelected: isSelected)
            stack.addArrangedSubview(button)
        }
    }

    private func makeTagChip(stat: MobileSearchTagStat, isActive: Bool) -> UIButton {
        var config = UIButton.Configuration.filled()
        let title = "#\(stat.tag)"
        config.attributedTitle = AttributedString(title, attributes: .init([
            .font: UIFont.systemFont(ofSize: 12, weight: .semibold),
        ]))
        config.baseForegroundColor = isActive ? ThemeUIKit.background : ThemeUIKit.text
        config.baseBackgroundColor = isActive ? ThemeUIKit.accent : UIColor(white: 0.16, alpha: 1.0)
        config.cornerStyle = .capsule
        config.contentInsets = NSDirectionalEdgeInsets(top: 5, leading: 8, bottom: 5, trailing: 8)

        let button = UIButton(configuration: config)
        button.addAction(UIAction { [weak self] _ in
            self?.onToggleTag?(stat)
        }, for: .touchUpInside)
        button.setContentCompressionResistancePriority(.required, for: .horizontal)
        return button
    }

    private func makeModelChip(model: String, shortName: String, isSelected: Bool) -> UIButton {
        var config = UIButton.Configuration.filled()
        config.attributedTitle = AttributedString(shortName, attributes: .init([
            .font: UIFont.systemFont(ofSize: 12, weight: .semibold),
        ]))
        config.baseForegroundColor = isSelected ? ThemeUIKit.background : ThemeUIKit.text
        config.baseBackgroundColor = isSelected ? ThemeUIKit.accent : UIColor(white: 0.16, alpha: 1.0)
        config.cornerStyle = .capsule
        config.contentInsets = NSDirectionalEdgeInsets(top: 5, leading: 8, bottom: 5, trailing: 8)

        let button = UIButton(configuration: config)
        button.addAction(UIAction { [weak self] _ in
            Haptics.play(.light)
            self?.onSelectModel?(model)
        }, for: .touchUpInside)
        button.setContentCompressionResistancePriority(.required, for: .horizontal)
        return button
    }
}

// MARK: - HomeKeyboardProxyView

private struct HomeKeyboardProxyView: UIViewRepresentable {
    let isChat: Bool
    @Binding var text: String
    let placeholder: String
    let focusTrigger: Int
    let onSubmit: () -> Void

    // Tag data
    let tagStats: [MobileSearchTagStat]
    let activeTagFilters: Set<String>
    let onToggleTag: (MobileSearchTagStat) -> Void

    // Model data
    let allModels: [String]
    let selectedModel: String
    let onSelectModel: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField()
        textField.font = .systemFont(ofSize: 17)
        textField.textColor = ThemeUIKit.text
        textField.tintColor = ThemeUIKit.accent
        textField.autocapitalizationType = .none
        textField.autocorrectionType = .no
        textField.returnKeyType = .default
        textField.attributedPlaceholder = NSAttributedString(
            string: placeholder,
            attributes: [.foregroundColor: ThemeUIKit.textMuted]
        )
        textField.delegate = context.coordinator
        textField.setContentHuggingPriority(.defaultLow, for: .horizontal)
        textField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        // Clear input assistant bar items (remove predictive bar above accessory)
        textField.inputAssistantItem.leadingBarButtonGroups = []
        textField.inputAssistantItem.trailingBarButtonGroups = []

        // Build chip toolbar as inputAccessoryView
        let toolbar = HomeChipToolbarView(
            frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 42)
        )
        toolbar.onToggleTag = { stat in
            onToggleTag(stat)
        }
        toolbar.onSelectModel = { model in
            onSelectModel(model)
        }
        context.coordinator.chipToolbar = toolbar

        textField.inputAccessoryView = toolbar
        textField.text = text

        return textField
    }

    func updateUIView(_ textField: UITextField, context: Context) {
        // Keep coordinator in sync with latest SwiftUI state
        context.coordinator.parent = self

        // Sync text from SwiftUI → UIKit (guard against loops)
        if !context.coordinator.isInternalUpdate && textField.text != text {
            textField.text = text
        }

        // Update placeholder
        textField.attributedPlaceholder = NSAttributedString(
            string: placeholder,
            attributes: [.foregroundColor: ThemeUIKit.textMuted]
        )

        // Focus trigger
        if context.coordinator.lastFocusTrigger != focusTrigger {
            context.coordinator.lastFocusTrigger = focusTrigger
            DispatchQueue.main.async {
                textField.becomeFirstResponder()
            }
        }

        // Update chip toolbar
        if let toolbar = context.coordinator.chipToolbar {
            toolbar.onToggleTag = { stat in onToggleTag(stat) }
            toolbar.onSelectModel = { model in onSelectModel(model) }

            if isChat {
                toolbar.updateModelChips(models: allModels, selectedModel: selectedModel)
            } else {
                toolbar.updateTagChips(tags: tagStats, activeFilters: activeTagFilters)
            }
        }
    }

    class Coordinator: NSObject, UITextFieldDelegate {
        var parent: HomeKeyboardProxyView
        var lastFocusTrigger: Int = 0
        var isInternalUpdate = false
        weak var chipToolbar: HomeChipToolbarView?

        init(parent: HomeKeyboardProxyView) {
            self.parent = parent
        }

        func textFieldDidChangeSelection(_ textField: UITextField) {
            let newText = textField.text ?? ""
            guard newText != parent.text else { return }
            isInternalUpdate = true
            parent.text = newText
            isInternalUpdate = false
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            parent.onSubmit()
            return false
        }
    }
}

// MARK: - MobileHomeInputBar

private struct MobileHomeInputBar: View {
    @Bindable var store: StoreOf<AppFeature>
    let tab: MobileHomeTab
    let focusTrigger: Int

    private var isChat: Bool { tab == .chat }

    private var textBinding: Binding<String> {
        Binding(
            get: { isChat ? store.chatInput : store.searchText },
            set: { newValue in
                if isChat {
                    store.send(.updateChatInput(newValue))
                } else {
                    store.send(.updateSearchText(newValue))
                }
            }
        )
    }

    private var placeholder: String {
        isChat ? "Ask AI..." : "Search notes"
    }

    private var actionIcon: String {
        isChat ? "arrow.up.circle.fill" : "square.and.pencil"
    }

    private var canSendChat: Bool {
        !store.chatInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var hasText: Bool {
        let text = isChat ? store.chatInput : store.searchText
        return !text.isEmpty
    }

    private var activeSearchTagFilters: Set<String> {
        Set(
            store.searchText
                .split(separator: " ", omittingEmptySubsequences: true)
                .filter { $0.hasPrefix("#") && $0.count > 1 }
                .map { String($0.dropFirst()).lowercased() }
        )
    }

    private var sortedTagFilters: [MobileSearchTagStat] {
        var counts: [String: Int] = [:]
        var canonicalTags: [String: String] = [:]

        for file in store.files {
            var seenInNote: Set<String> = []
            for rawTag in file.tags {
                let trimmed = rawTag.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { continue }
                let normalized = trimmed.lowercased()
                guard !seenInNote.contains(normalized) else { continue }
                seenInNote.insert(normalized)

                counts[normalized, default: 0] += 1
                if canonicalTags[normalized] == nil {
                    canonicalTags[normalized] = trimmed
                }
            }
        }

        return counts.map { normalized, count in
            MobileSearchTagStat(
                tag: canonicalTags[normalized] ?? normalized,
                normalizedTag: normalized,
                count: count
            )
        }
        .sorted { lhs, rhs in
            if lhs.count != rhs.count {
                return lhs.count > rhs.count
            }
            return lhs.tag.localizedCaseInsensitiveCompare(rhs.tag) == .orderedAscending
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: isChat ? "sparkles" : "magnifyingglass")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Theme.textMuted)

                HomeKeyboardProxyView(
                    isChat: isChat,
                    text: textBinding,
                    placeholder: placeholder,
                    focusTrigger: focusTrigger,
                    onSubmit: { submitFromKeyboard() },
                    tagStats: sortedTagFilters,
                    activeTagFilters: activeSearchTagFilters,
                    onToggleTag: { stat in
                        Haptics.play(.selection)
                        toggleSearchTagFilter(stat)
                    },
                    allModels: store.allModels,
                    selectedModel: store.selectedModel,
                    onSelectModel: { model in
                        store.send(.updateModel(model))
                    }
                )

                if hasText {
                    Button {
                        Haptics.play(.light)
                        if isChat {
                            store.send(.updateChatInput(""))
                            store.send(.updateChatMentionQuery(nil))
                        } else {
                            store.send(.clearSearch)
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Theme.textMuted)
                            .font(.system(size: 14))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear input")
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 46)
            .background(Theme.backgroundTertiary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

            Button {
                submitPrimaryAction()
            } label: {
                Image(systemName: actionIcon)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(isChat && !canSendChat ? Theme.textMuted : Theme.text)
                    .frame(width: 46, height: 46)
                    .background(Theme.backgroundTertiary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(isChat && !canSendChat)
            .accessibilityLabel(isChat ? "Send message" : "Create note")
        }
    }

    private func submitFromKeyboard() {
        if isChat {
            guard canSendChat else { return }
            Haptics.play(.light)
            store.send(.sendChatMessage(store.chatInput))
        } else {
            Haptics.play(.light)
            store.send(.submitSearch)
        }
    }

    private func submitPrimaryAction() {
        if isChat {
            submitFromKeyboard()
        } else {
            Haptics.play(.light)
            let query = store.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            if query.isEmpty {
                store.send(.createNewNote)
            } else {
                store.send(.createNoteFromSearch)
            }
        }
    }

    private func toggleSearchTagFilter(_ stat: MobileSearchTagStat) {
        let tokens = store.searchText.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        var updatedTokens: [String] = []
        var removedTarget = false

        for token in tokens {
            guard token.hasPrefix("#"), token.count > 1 else {
                updatedTokens.append(token)
                continue
            }
            let normalized = String(token.dropFirst()).lowercased()
            if normalized == stat.normalizedTag {
                removedTarget = true
                continue
            }
            updatedTokens.append(token)
        }

        if !removedTarget {
            updatedTokens.append("#\(stat.tag)")
        }

        store.send(.updateSearchText(updatedTokens.joined(separator: " ")))
        store.send(.updateSearchTagQuery(nil))
    }
}

private struct MobileSearchTagStat: Identifiable {
    let tag: String
    let normalizedTag: String
    let count: Int

    var id: String { normalizedTag }
}

private struct MobileTabButton: View {
    let title: String
    let systemImage: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.play(.selection)
            action()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .semibold))
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundStyle(isSelected ? Theme.background : Theme.textMuted)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule(style: .continuous)
                    .fill(isSelected ? Theme.accent : Theme.backgroundTertiary)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}

private struct MobileNoteRow: View {
    let file: MarkdownFile
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            Group {
                if let icon = file.icon, !icon.isEmpty {
                    Text(icon)
                        .font(.system(size: 18))
                } else {
                    Image(systemName: file.isDownloaded ? "doc.text" : "icloud.and.arrow.down")
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.textMuted)
                }
            }
            .frame(width: 24)

            VStack(alignment: .leading, spacing: 3) {
                Text(file.title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    if let modified = file.lastModified {
                        Text(RelativeTime.string(from: modified))
                            .font(.caption)
                            .foregroundStyle(Theme.textMuted)
                    }
                    if !file.tags.isEmpty {
                        Text(file.tags.prefix(3).joined(separator: " "))
                            .font(.caption)
                            .foregroundStyle(Theme.accent)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()

            if file.hasConflict {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(isSelected ? Theme.selection : Theme.backgroundSecondary)
        )
    }
}
#endif
