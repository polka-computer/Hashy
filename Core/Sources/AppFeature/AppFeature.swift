import AIFeature
import ComposableArchitecture
import Foundation
import MarkdownStorage
import OSLog
import Sharing

#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

// MARK: - Sort

public enum SortField: String, Equatable, Sendable {
    case updated, created, name
}

// MARK: - Reducer

private let appSyncLogger = Logger(subsystem: "ca.long.tail.labs.hashy", category: "AppSync")

@Reducer
public struct AppFeature: Sendable {
    @ObservableState
    public struct State: Equatable {
        public var files: [MarkdownFile] = []
        public var selectedFileURL: URL?
        public var editorContent: String = ""
        public var currentFrontmatter: NoteFrontmatter = NoteFrontmatter()
        public var hasUnsavedChanges: Bool = false
        public var isSidebarVisible: Bool = true
        public var isChatVisible: Bool = false
        public var isCloudAvailable: Bool = false
        public var isZenMode: Bool = false
        @Shared(.iCloud("isDarkMode")) public var isDarkMode: Bool = true
        @Shared(.iCloud("openRouterAPIKey")) public var openRouterAPIKey: String = ""
        @Shared(.iCloud("openAIAPIKey")) public var openAIAPIKey: String = ""
        @Shared(.iCloud("anthropicAPIKey")) public var anthropicAPIKey: String = ""
        @Shared(.iCloud("selectedModel")) public var selectedModel: String = "anthropic/claude-sonnet-4.5"
        @Shared(.iCloud("customModels")) public var customModels: String = ""
        public var isSettingsVisible: Bool = false

        // Vault folder
        public var vaultPath: String = ""
        public var showVaultSetupPrompt: Bool = false

        // Sync status
        public var syncSummary: SyncSummary = SyncSummary()

        // Conflict
        public var activeConflict: FileConflict?

        // Sort (persisted + synced via iCloud KVS)
        @Shared(.iCloud("sortField")) public var sortField: SortField = .updated
        @Shared(.iCloud("sortAscending")) public var sortAscending: Bool = false

        // Search / nvALT
        public var searchText: String = ""
        public var searchFocusTrigger: Int = 0

        // Search tag autocomplete
        public var searchTagQuery: String?

        // Editor focus
        public var editorFocusTrigger: Int = 0

        // Navigation history
        public var navigationHistory: [URL] = []
        public var navigationIndex: Int = -1
        public var canNavigateBack: Bool { navigationIndex > 0 }
        public var canNavigateForward: Bool { navigationIndex < navigationHistory.count - 1 }

        // Rename (frontmatter title)
        public var renamingFileURL: URL?
        public var renameText: String = ""

        // Chat
        public var chatMessages: [ChatMessage] = []
        public var chatInput: String = ""
        public var isChatLoading: Bool = false
        public var chatError: String?
        public var chatMentionQuery: String?
        public var chatFocusTrigger: Int = 0

        /// Files matching the current @mention query in chat.
        public var chatMentionSuggestions: [MarkdownFile] {
            guard let query = chatMentionQuery else { return [] }
            if query.isEmpty { return Array(files.prefix(8)) }
            let q = query.lowercased()
            return files.filter {
                $0.title.lowercased().contains(q) || $0.name.lowercased().contains(q)
            }
        }

        /// The currently selected file, looked up by URL from the files array.
        public var selectedFile: MarkdownFile? {
            guard let url = selectedFileURL else { return nil }
            return files.first { $0.url == url }
        }

        /// Display title: prefers frontmatter title, falls back to file title.
        public var displayTitle: String {
            if let t = currentFrontmatter.title, !t.isEmpty { return t }
            return selectedFile?.title ?? ""
        }

        /// Display icon: prefers frontmatter icon, falls back to file icon.
        public var displayIcon: String? {
            if let i = currentFrontmatter.icon, !i.isEmpty { return i }
            return selectedFile?.icon
        }

        /// Display tags from frontmatter.
        public var displayTags: [String] {
            currentFrontmatter.tags
        }

        // Computed: filtered files
        public var filteredFiles: [MarkdownFile] {
            let base: [MarkdownFile]
            if searchText.isEmpty {
                base = files
            } else {
                // Parse #tag tokens vs text query
                let tokens = searchText.split(separator: " ", omittingEmptySubsequences: true)
                let tagFilters = tokens.filter { $0.hasPrefix("#") && $0.count > 1 }.map { String($0.dropFirst()).lowercased() }
                let textTokens = tokens.filter { !$0.hasPrefix("#") || $0.count <= 1 }
                let textQuery = textTokens.joined(separator: " ").lowercased()

                base = files.filter { file in
                    // Must match ALL tag filters
                    let matchesTags = tagFilters.allSatisfy { tag in
                        file.tags.contains { $0.lowercased() == tag }
                    }
                    // Must match text query (if any)
                    let matchesText = textQuery.isEmpty ||
                        file.title.lowercased().contains(textQuery) ||
                        file.name.lowercased().contains(textQuery) ||
                        file.tags.contains { $0.lowercased().contains(textQuery) }
                    return matchesTags && matchesText
                }
            }

            return base.sorted { a, b in
                let result: Bool
                switch sortField {
                case .updated:
                    result = (a.lastModified ?? .distantPast) > (b.lastModified ?? .distantPast)
                case .created:
                    result = (a.createdDate ?? .distantPast) > (b.createdDate ?? .distantPast)
                case .name:
                    result = a.title.localizedCaseInsensitiveCompare(b.title) == .orderedAscending
                }
                return sortAscending ? !result : result
            }
        }

        /// All unique tags across every file, sorted alphabetically.
        public var allTags: [String] {
            let all = files.flatMap { $0.tags }
            return Array(Set(all)).sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
        }

        /// Tags matching the current search tag query.
        public var searchTagSuggestions: [String] {
            guard let query = searchTagQuery, !query.isEmpty else { return allTags }
            let q = query.lowercased()
            return allTags.filter { $0.lowercased().contains(q) }
        }

        /// Whether the search text exactly matches an existing file title or name.
        public var searchMatchesExistingFile: Bool {
            guard !searchText.isEmpty else { return false }
            let query = searchText.lowercased()
            return files.contains { file in
                file.title.lowercased() == query || file.name.lowercased() == query
            }
        }

        /// Custom models parsed from comma-separated storage.
        public var customModelList: [String] {
            customModels.split(separator: ",").map { String($0.trimmingCharacters(in: .whitespaces)) }.filter { !$0.isEmpty }
        }

        /// Models available based on which API keys are set.
        public var availableModels: [String] {
            var models: [String] = []
            if !openRouterAPIKey.isEmpty { models += AIModels.openRouter }
            if !openAIAPIKey.isEmpty { models += AIModels.openAI }
            if !anthropicAPIKey.isEmpty { models += AIModels.anthropic }
            if models.isEmpty { models = AIModels.openRouter }
            return models + customModelList
        }

        /// All models (alias for availableModels).
        public var allModels: [String] { availableModels }

        public init() {}
    }


    public enum Action: Equatable, Sendable {
        // Lifecycle
        case onAppear
        case filesUpdated([MarkdownFile])

        // Sort
        case setSortField(SortField)
        case toggleSortDirection

        // File selection & editing
        case selectFile(MarkdownFile?)
        case fileContentLoaded(String)
        case updateEditorContent(String)
        case insertEditorSnippet(String)
        case saveCurrentFile
        case fileSaved

        // File operations
        case deleteCurrentNote
        case deleteFile(MarkdownFile)
        case startRenameFile(MarkdownFile)
        case submitRename(String)
        case cancelRename

        // New note
        case createNewNote
        case createNoteFromSearch
        case focusEditor

        // Search / nvALT
        case updateSearchText(String)
        case submitSearch
        case clearSearch
        case focusSearch
        case selectNextFile
        case selectPreviousFile

        // Search tag autocomplete
        case updateSearchTagQuery(String?)
        case insertSearchTag(String)

        // Navigation
        case navigateBack
        case navigateForward

        // Icon picker
        case updateFileIcon(String)

        // Tags
        case addTag(String)
        case removeTag(String)

        // Chat
        case sendChatMessage(String)
        case chatResponseReceived(String)
        case chatErrorReceived(String)
        case toolCallLogged(String)
        case clearChat
        case updateChatInput(String)
        case updateChatMentionQuery(String?)
        case insertChatMention(MarkdownFile)

        // Settings
        case setSettingsVisible(Bool)
        case updateAPIKey(String)
        case updateOpenAIAPIKey(String)
        case updateAnthropicAPIKey(String)
        case updateModel(String)
        case addCustomModel(String)
        case removeCustomModel(String)

        // Vault folder
        case chooseVaultFolder
        case vaultFolderChosen(URL)
        case resetVaultFolder
        case revealVaultInFinder
        case dismissVaultSetup(Bool)

        // Sync status
        case syncSummaryUpdated(SyncSummary)

        // Conflicts
        case conflictDetected(FileConflict)
        case resolveConflict(ConflictResolution)
        case conflictResolved

        // External file change (from DocumentPresenter)
        case externalFileChange(URL)

        // UI
        case toggleSidebar
        case toggleChat
        case openChat
        case toggleDarkMode
        case toggleZenMode
        case openInApp(String)
        case copyVaultPath
    }

    @Dependency(\.aiClient) var aiClient

    /// Cancellation ID for the file-watching long-running effect.
    private enum FileWatcherID: Hashable { case watcher }

    /// Shared sync state store for hash-based conflict detection.
    nonisolated(unsafe) private static var _syncStore: SyncStateStore?
    private static var syncStore: SyncStateStore {
        if let store = _syncStore { return store }
        let store = SyncStateStore()
        _syncStore = store
        return store
    }

    nonisolated(unsafe) private static var presenterContinuation: AsyncStream<URL?>.Continuation?

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .setSortField(field):
                state.$sortField.withLock { $0 = field }
                return .none

              case .toggleSortDirection:
                  state.$sortAscending.withLock { $0.toggle() }
                  return .none

              case .onAppear:
                  NSUbiquitousKeyValueStore.default.synchronize()
                  state.isCloudAvailable = CloudContainerProvider.isCloudAvailable
                  state.vaultPath = CloudContainerProvider.currentDirectoryDescription
                  let cloudAvailable = state.isCloudAvailable
                  let vaultPath = state.vaultPath
                  let bundleID = Bundle.main.bundleIdentifier ?? "unknown"
                  appSyncLogger.info(
                      "App appeared. cloudAvailable=\(cloudAvailable, privacy: .public) vault=\(vaultPath, privacy: .public) bundleID=\(bundleID, privacy: .public)"
                  )
                  // On iOS, prompt user to pick iCloud Drive folder if iCloud is signed in
                  // but no custom directory is set yet
                  #if os(iOS)
                  if !CloudContainerProvider.isUsingCustomDirectory && CloudContainerProvider.isICloudSignedIn {
                      state.showVaultSetupPrompt = true
                  }
                  #endif
                  return startFileWatcher()

            // MARK: - Vault Folder

            case .chooseVaultFolder:
                #if os(macOS)
                return .run { send in
                    let url = await MainActor.run { () -> URL? in
                        let panel = NSOpenPanel()
                        panel.canChooseDirectories = true
                        panel.canChooseFiles = false
                        panel.allowsMultipleSelection = false
                        panel.message = "Choose a folder for your notes vault"
                        panel.prompt = "Choose"
                        let response = panel.runModal()
                        return response == .OK ? panel.url : nil
                    }
                    if let url {
                        await send(.vaultFolderChosen(url))
                    }
                }
                #else
                // iOS: handled by FolderPickerCoordinator which calls vaultFolderChosen
                return .none
                #endif

            case let .vaultFolderChosen(url):
                state.showVaultSetupPrompt = false
                do {
                    try CloudContainerProvider.setCustomDirectory(url: url)
                    state.vaultPath = CloudContainerProvider.currentDirectoryDescription
                    state.isCloudAvailable = CloudContainerProvider.isCloudAvailable
                } catch {
                    // Bookmark creation failed — leave current setting
                }
                return .merge(
                    .cancel(id: FileWatcherID.watcher),
                    startFileWatcher()
                )

            case .resetVaultFolder:
                CloudContainerProvider.clearCustomDirectory()
                state.vaultPath = CloudContainerProvider.currentDirectoryDescription
                state.isCloudAvailable = CloudContainerProvider.isCloudAvailable
                return .merge(
                    .cancel(id: FileWatcherID.watcher),
                    startFileWatcher()
                )

            case let .dismissVaultSetup(show):
                state.showVaultSetupPrompt = show
                return .none

            case .revealVaultInFinder:
                #if os(macOS)
                let docsURL = CloudContainerProvider.documentsDirectory()
                return .run { _ in
                    NSWorkspace.shared.open(docsURL)
                }
                #else
                return .none
                #endif

            // MARK: - Sync Status

            case let .syncSummaryUpdated(summary):
                state.syncSummary = summary
                return .none

            // MARK: - Conflicts

            case let .conflictDetected(conflict):
                state.activeConflict = conflict
                return .none

            case let .resolveConflict(resolution):
                guard let conflict = state.activeConflict else { return .none }
                let relativePath = state.selectedFile?.relativePath ?? conflict.fileURL.lastPathComponent
                state.activeConflict = nil
                let store = Self.syncStore
                return .run { send in
                    ConflictDetector.resolve(conflict, keeping: resolution, syncStore: store, relativePath: relativePath)
                    await send(.conflictResolved)
                }

            case .conflictResolved:
                guard let file = state.selectedFile else { return .none }
                let store = Self.syncStore
                return .run { send in
                    let content = try MarkdownDocument.loadContent(of: file)
                    let modDate = (try? file.url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date()
                    store.record(relativePath: file.relativePath, content: content, modDate: modDate)
                    await send(.fileContentLoaded(content))
                }

            // MARK: - External File Change

            case let .externalFileChange(url):
                guard let selectedURL = state.selectedFileURL, selectedURL == url else { return .none }
                if state.hasUnsavedChanges {
                    // Detect conflict — user has unsaved changes and file changed externally
                    let unsavedContent = FrontmatterParser.update(state.currentFrontmatter, in: state.editorContent)
                    let relativePath = state.selectedFile?.relativePath ?? url.lastPathComponent
                    let store = Self.syncStore
                    return .run { send in
                        if let conflict = ConflictDetector.detect(
                            at: url,
                            unsavedContent: unsavedContent,
                            syncStore: store,
                            relativePath: relativePath
                        ) {
                            await send(.conflictDetected(conflict))
                        }
                    }
                } else {
                    // No unsaved changes — just reload
                    guard let file = state.selectedFile else { return .none }
                    let store = Self.syncStore
                    return .run { send in
                        let content = try MarkdownDocument.loadContent(of: file)
                        // Record the loaded content so we can detect future external changes
                        let modDate = (try? file.url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date()
                        store.record(relativePath: file.relativePath, content: content, modDate: modDate)
                        await send(.fileContentLoaded(content))
                    }
                }

            case let .selectFile(file):
                // Push to navigation history
                if let url = file?.url {
                    // Truncate forward stack
                    if state.navigationIndex < state.navigationHistory.count - 1 {
                        state.navigationHistory = Array(state.navigationHistory.prefix(state.navigationIndex + 1))
                    }
                    // Deduplicate consecutive
                    if state.navigationHistory.last != url {
                        state.navigationHistory.append(url)
                    }
                    state.navigationIndex = state.navigationHistory.count - 1
                }
                return Self.selectFileCore(file, state: &state)

            case .navigateBack:
                guard state.canNavigateBack else { return .none }
                state.navigationIndex -= 1
                let url = state.navigationHistory[state.navigationIndex]
                let file = state.files.first { $0.url == url }
                return Self.selectFileCore(file, state: &state)

            case .navigateForward:
                guard state.canNavigateForward else { return .none }
                state.navigationIndex += 1
                let url = state.navigationHistory[state.navigationIndex]
                let file = state.files.first { $0.url == url }
                return Self.selectFileCore(file, state: &state)

            case let .fileContentLoaded(content):
                state.currentFrontmatter = FrontmatterParser.parse(from: content) ?? NoteFrontmatter()
                state.editorContent = FrontmatterParser.body(of: content)
                state.hasUnsavedChanges = false
                return .none

            case let .updateEditorContent(content):
                state.editorContent = content
                state.hasUnsavedChanges = true
                return .none

            case let .insertEditorSnippet(snippet):
                let trimmed = snippet.trimmingCharacters(in: .newlines)
                guard !trimmed.isEmpty else { return .none }
                state.editorContent = Self.appendSnippet(snippet, to: state.editorContent)
                state.hasUnsavedChanges = true
                return .send(.saveCurrentFile)

            case .saveCurrentFile:
                guard let file = state.selectedFile, !file.isDirectory else { return .none }
                let fullContent = FrontmatterParser.update(state.currentFrontmatter, in: state.editorContent)
                let store = Self.syncStore
                return .run { send in
                    try MarkdownDocument.saveContent(fullContent, to: file)
                    // Record saved content in sync store
                    let modDate = (try? file.url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date()
                    store.record(relativePath: file.relativePath, content: fullContent, modDate: modDate)
                    await send(.fileSaved)
                }

            case .fileSaved:
                state.hasUnsavedChanges = false
                return .none

            case .deleteCurrentNote:
                guard let file = state.selectedFile, !file.isDirectory else { return .none }
                return .send(.deleteFile(file))

            case let .deleteFile(file):
                if state.selectedFileURL == file.url {
                    state.selectedFileURL = nil
                    state.editorContent = ""
                    state.currentFrontmatter = NoteFrontmatter()
                }
                let store = Self.syncStore
                return .run { _ in
                    try MarkdownDocument.deleteFile(file)
                    store.remove(relativePath: file.relativePath)
                }

            case let .startRenameFile(file):
                state.renamingFileURL = file.url
                state.renameText = file.title
                return .none

            case let .submitRename(newName):
                guard state.renamingFileURL != nil,
                      !newName.trimmingCharacters(in: .whitespaces).isEmpty else {
                    state.renamingFileURL = nil
                    return .none
                }
                state.renamingFileURL = nil
                state.currentFrontmatter.title = newName
                state.hasUnsavedChanges = true
                return .send(.saveCurrentFile)

            case .cancelRename:
                state.renamingFileURL = nil
                return .none

            // MARK: - New Note

            case .createNewNote:
                let parentDir = CloudContainerProvider.documentsDirectory()
                return .run { send in
                    let url = try MarkdownDocument.createFile(name: "Untitled", in: parentDir, content: "")
                    let file = MarkdownFile(
                        url: url,
                        name: "Untitled",
                        relativePath: url.lastPathComponent,
                        isDownloaded: true,
                        lastModified: Date(),
                        isDirectory: false
                    )
                    await send(.selectFile(file))
                    await send(.focusEditor)
                }

            case .createNoteFromSearch:
                let text = state.searchText.trimmingCharacters(in: .whitespaces)
                state.searchText = ""
                state.searchTagQuery = nil
                guard !text.isEmpty else { return .send(.createNewNote) }
                let tokens = text.split(separator: " ", omittingEmptySubsequences: true)
                let extractedTags = tokens.filter { $0.hasPrefix("#") && $0.count > 1 }.map { String($0.dropFirst()) }
                let titleTokens = tokens.filter { !$0.hasPrefix("#") || $0.count <= 1 }
                let titleText = titleTokens.joined(separator: " ")
                let fileName = titleText.isEmpty ? extractedTags.first ?? "Untitled" : String(titleText)
                let parentDir = CloudContainerProvider.documentsDirectory()
                return .run { send in
                    let url = try MarkdownDocument.createFile(name: fileName, in: parentDir, content: titleText, tags: extractedTags)
                    let file = MarkdownFile(
                        url: url,
                        name: fileName,
                        relativePath: url.lastPathComponent,
                        isDownloaded: true,
                        lastModified: Date(),
                        isDirectory: false,
                        tags: extractedTags
                    )
                    await send(.selectFile(file))
                    await send(.focusEditor)
                }

            case .focusEditor:
                state.editorFocusTrigger += 1
                return .none

            // MARK: - Search / nvALT

            case let .updateSearchText(text):
                state.searchText = text
                // Detect #tag typing for autocomplete
                if let lastHash = text.lastIndex(of: "#") {
                    let afterHash = text[text.index(after: lastHash)...]
                    if !afterHash.contains(" ") {
                        state.searchTagQuery = String(afterHash)
                    } else {
                        state.searchTagQuery = nil
                    }
                } else {
                    state.searchTagQuery = nil
                }
                return .none

            case .submitSearch:
                let filtered = state.filteredFiles
                if let selectedURL = state.selectedFileURL,
                   filtered.contains(where: { $0.url == selectedURL }) {
                    state.searchText = ""
                    return .send(.focusEditor)
                } else if let first = filtered.first {
                    state.searchText = ""
                    return .merge(.send(.selectFile(first)), .send(.focusEditor))
                } else if !state.searchText.trimmingCharacters(in: .whitespaces).isEmpty {
                    let text = state.searchText.trimmingCharacters(in: .whitespaces)
                    state.searchText = ""
                    state.searchTagQuery = nil
                    // Extract #tags from text
                    let tokens = text.split(separator: " ", omittingEmptySubsequences: true)
                    let extractedTags = tokens.filter { $0.hasPrefix("#") && $0.count > 1 }.map { String($0.dropFirst()) }
                    let titleTokens = tokens.filter { !$0.hasPrefix("#") || $0.count <= 1 }
                    let titleText = titleTokens.joined(separator: " ")
                    let fileName = titleText.isEmpty ? extractedTags.first ?? "Untitled" : String(titleText.split(separator: " ", maxSplits: 5).prefix(5).joined(separator: " "))
                    let parentDir = CloudContainerProvider.documentsDirectory()
                    return .run { send in
                        let url = try MarkdownDocument.createFile(name: fileName, in: parentDir, content: titleText, tags: extractedTags)
                        let file = MarkdownFile(
                            url: url,
                            name: fileName,
                            relativePath: url.lastPathComponent,
                            isDownloaded: true,
                            lastModified: Date(),
                            isDirectory: false,
                            tags: extractedTags
                        )
                        await send(.selectFile(file))
                        await send(.focusEditor)
                    }
                }
                return .none

            case .clearSearch:
                state.searchText = ""
                return .none

            case .focusSearch:
                state.searchText = ""
                state.searchFocusTrigger += 1
                return .none

            case .selectNextFile:
                let filtered = state.filteredFiles
                guard !filtered.isEmpty else { return .none }
                if let currentURL = state.selectedFileURL,
                   let idx = filtered.firstIndex(where: { $0.url == currentURL }),
                   idx + 1 < filtered.count {
                    return .send(.selectFile(filtered[idx + 1]))
                } else {
                    return .send(.selectFile(filtered.first))
                }

            case .selectPreviousFile:
                let filtered = state.filteredFiles
                guard !filtered.isEmpty else { return .none }
                if let currentURL = state.selectedFileURL,
                   let idx = filtered.firstIndex(where: { $0.url == currentURL }),
                   idx > 0 {
                    return .send(.selectFile(filtered[idx - 1]))
                } else {
                    return .send(.selectFile(filtered.last))
                }

            // MARK: - Search Tag Autocomplete

            case let .updateSearchTagQuery(query):
                state.searchTagQuery = query
                return .none

            case let .insertSearchTag(tag):
                // Replace the partial #query with #tag
                var text = state.searchText
                // Find the last # token and replace it
                if let hashRange = text.range(of: "#", options: .backwards) {
                    let afterHash = text[hashRange.upperBound...]
                    // If there's no space after the #, replace everything from # to end
                    if !afterHash.contains(" ") {
                        text = String(text[..<hashRange.lowerBound]) + "#\(tag) "
                    } else {
                        text += "#\(tag) "
                    }
                } else {
                    text += "#\(tag) "
                }
                state.searchText = text
                state.searchTagQuery = nil
                return .none

            // MARK: - Icon Picker

            case let .updateFileIcon(emoji):
                guard state.selectedFileURL != nil else { return .none }
                state.currentFrontmatter.icon = emoji.isEmpty ? nil : emoji
                state.hasUnsavedChanges = true
                return .send(.saveCurrentFile)

            // MARK: - Tags

            case let .addTag(tag):
                guard state.selectedFileURL != nil else { return .none }
                let trimmed = tag.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty else { return .none }
                // Case-insensitive duplicate check
                guard !state.currentFrontmatter.tags.contains(where: { $0.lowercased() == trimmed.lowercased() }) else { return .none }
                state.currentFrontmatter.tags.append(trimmed)
                state.hasUnsavedChanges = true
                return .send(.saveCurrentFile)

            case let .removeTag(tag):
                guard state.selectedFileURL != nil else { return .none }
                state.currentFrontmatter.tags.removeAll { $0.lowercased() == tag.lowercased() }
                state.hasUnsavedChanges = true
                return .send(.saveCurrentFile)

            // MARK: - Chat

            case let .sendChatMessage(content):
                guard !content.trimmingCharacters(in: .whitespaces).isEmpty else { return .none }
                let userMessage = ChatMessage(role: .user, content: content)
                state.chatMessages.append(userMessage)
                state.chatInput = ""
                state.chatMentionQuery = nil
                state.chatError = nil
                state.isChatLoading = true

                // Parse @[Title] mentions and resolve note contents
                var enrichedContext = ""
                let mentionPattern = try? NSRegularExpression(pattern: #"@\[([^\]]+)\]"#)
                let nsContent = content as NSString
                let mentionMatches = mentionPattern?.matches(in: content, range: NSRange(location: 0, length: nsContent.length)) ?? []
                for match in mentionMatches {
                    let titleRange = match.range(at: 1)
                    let title = nsContent.substring(with: titleRange)
                    if let file = state.files.first(where: { $0.title.lowercased() == title.lowercased() || $0.name.lowercased() == title.lowercased() }),
                       let fileContent = try? MarkdownDocument.loadContent(of: file) {
                        enrichedContext += "\n---\nReferenced note \"\(title)\":\n\(fileContent)\n"
                    }
                }

                let apiKeys = APIKeys(
                    openRouter: state.openRouterAPIKey,
                    openAI: state.openAIAPIKey,
                    anthropic: state.anthropicAPIKey
                )
                let model = state.selectedModel
                // Build messages with enriched context prepended to the last user message
                var messages = state.chatMessages
                if !enrichedContext.isEmpty, let lastIndex = messages.indices.last {
                    let enrichedContent = enrichedContext + "\n---\nUser message:\n" + messages[lastIndex].content
                    messages[lastIndex] = ChatMessage(
                        id: messages[lastIndex].id,
                        role: .user,
                        content: enrichedContent,
                        timestamp: messages[lastIndex].timestamp
                    )
                }
                let noteContext = state.editorContent
                let toolContext = NoteToolContext(
                    files: state.files,
                    selectedFileURL: state.selectedFileURL,
                    editorContent: state.editorContent,
                    documentsDirectory: CloudContainerProvider.documentsDirectory()
                )
                let finalMessages = messages

                return .run { [aiClient] send in
                    do {
                        let result = try await aiClient.sendMessage(apiKeys, model, finalMessages, noteContext, toolContext) { summary in
                            await send(.toolCallLogged(summary))
                        }
                        await send(.chatResponseReceived(result.text))
                        if let url = result.createdNoteURLs.last {
                            let name = url.deletingPathExtension().lastPathComponent
                            let file = MarkdownFile(
                                url: url,
                                name: name,
                                relativePath: url.lastPathComponent,
                                isDownloaded: true,
                                lastModified: Date(),
                                isDirectory: false
                            )
                            await send(.selectFile(file))
                            await send(.focusEditor)
                        }
                    } catch {
                        await send(.chatErrorReceived(error.localizedDescription))
                    }
                }

            case let .chatResponseReceived(content):
                let assistantMessage = ChatMessage(role: .assistant, content: content)
                state.chatMessages.append(assistantMessage)
                state.isChatLoading = false
                return .none

            case let .toolCallLogged(summary):
                state.chatMessages.append(ChatMessage(role: .tool, content: summary))
                return .none

            case let .chatErrorReceived(error):
                state.chatError = error
                state.isChatLoading = false
                return .none

            case .clearChat:
                state.chatMessages = []
                state.chatError = nil
                return .none

            case let .updateChatInput(text):
                state.chatInput = text
                // Detect @mention query
                if let atIndex = text.lastIndex(of: "@") {
                    let afterAt = text[text.index(after: atIndex)...]
                    // Only show suggestions if no closing ] bracket yet
                    if !afterAt.contains("]") && !afterAt.contains("\n") {
                        // Check if we're inside a @[...] pattern or bare @query
                        if afterAt.hasPrefix("[") {
                            // Inside @[...] — query is text after [
                            let insideBracket = afterAt.dropFirst()
                            state.chatMentionQuery = String(insideBracket)
                        } else if !afterAt.contains(" ") {
                            state.chatMentionQuery = String(afterAt)
                        } else {
                            state.chatMentionQuery = nil
                        }
                    } else {
                        state.chatMentionQuery = nil
                    }
                } else {
                    state.chatMentionQuery = nil
                }
                return .none

            case let .updateChatMentionQuery(query):
                state.chatMentionQuery = query
                return .none

            case let .insertChatMention(file):
                // Replace the @query with @[Note Title]
                var text = state.chatInput
                if let atIndex = text.lastIndex(of: "@") {
                    text = String(text[..<atIndex]) + "@[\(file.title)] "
                } else {
                    text += "@[\(file.title)] "
                }
                state.chatInput = text
                state.chatMentionQuery = nil
                return .none

            // MARK: - Settings

            case let .setSettingsVisible(visible):
                state.isSettingsVisible = visible
                return .none

            case let .updateAPIKey(key):
                state.$openRouterAPIKey.withLock { $0 = key }
                return .none

            case let .updateOpenAIAPIKey(key):
                state.$openAIAPIKey.withLock { $0 = key }
                return .none

            case let .updateAnthropicAPIKey(key):
                state.$anthropicAPIKey.withLock { $0 = key }
                return .none

            case let .updateModel(model):
                state.$selectedModel.withLock { $0 = model }
                return .none

            case let .addCustomModel(model):
                let trimmed = model.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty else { return .none }
                var list = state.customModelList
                let builtIn = AIModels.openRouter + AIModels.openAI + AIModels.anthropic
                guard !list.contains(trimmed), !builtIn.contains(trimmed) else { return .none }
                list.append(trimmed)
                state.$customModels.withLock { $0 = list.joined(separator: ",") }
                state.$selectedModel.withLock { $0 = trimmed }
                return .none

            case let .removeCustomModel(model):
                var list = state.customModelList
                list.removeAll { $0 == model }
                state.$customModels.withLock { $0 = list.joined(separator: ",") }
                if state.selectedModel == model {
                    state.$selectedModel.withLock { $0 = AIModels.openRouter[0] }
                }
                return .none

            // MARK: - UI

            case let .filesUpdated(files):
                let previousModified = state.selectedFile?.lastModified
                state.files = files
                // Reload selected file if it was modified externally (e.g. by AI tool call)
                if let selectedURL = state.selectedFileURL,
                   !state.hasUnsavedChanges,
                   let updatedFile = files.first(where: { $0.url == selectedURL }),
                   updatedFile.lastModified != previousModified {
                    return .run { send in
                        let content = try MarkdownDocument.loadContent(of: updatedFile)
                        await send(.fileContentLoaded(content))
                    }
                }
                return .none

            case .toggleSidebar:
                state.isSidebarVisible.toggle()
                return .none

            case .toggleChat:
                state.isChatVisible.toggle()
                if state.isChatVisible {
                    state.chatFocusTrigger += 1
                }
                return .none

            case .openChat:
                state.isChatVisible = true
                state.chatFocusTrigger += 1
                return .none

            case .toggleDarkMode:
                state.$isDarkMode.withLock { $0.toggle() }
                return .none

            case .toggleZenMode:
                state.isZenMode.toggle()
                if state.isZenMode {
                    state.isSidebarVisible = false
                    state.isChatVisible = false
                } else {
                    state.isSidebarVisible = true
                }
                return .none

            case let .openInApp(appName):
                let docsURL = CloudContainerProvider.documentsDirectory()
                return .run { _ in
                    #if os(macOS)
                    switch appName {
                    case "Finder":
                        NSWorkspace.shared.open(docsURL)
                    case "iTerm":
                        _ = try? await NSWorkspace.shared.open(
                            [docsURL],
                            withApplicationAt: URL(fileURLWithPath: "/Applications/iTerm.app"),
                            configuration: NSWorkspace.OpenConfiguration()
                        )
                    case "Warp":
                        _ = try? await NSWorkspace.shared.open(
                            [docsURL],
                            withApplicationAt: URL(fileURLWithPath: "/Applications/Warp.app"),
                            configuration: NSWorkspace.OpenConfiguration()
                        )
                    case "Cursor":
                        Process.launchedProcess(launchPath: "/usr/bin/open", arguments: ["-a", "Cursor", docsURL.path])
                    case "VS Code":
                        Process.launchedProcess(launchPath: "/usr/bin/open", arguments: ["-a", "Visual Studio Code", docsURL.path])
                    default:
                        break
                    }
                    #endif
                }

            case .copyVaultPath:
                let docsURL = CloudContainerProvider.documentsDirectory()
                return .run { _ in
                    #if os(macOS)
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(docsURL.path, forType: .string)
                    #else
                    UIPasteboard.general.string = docsURL.path
                    #endif
                }
            }
        }
    }

    // MARK: - Helpers

    private static func selectFileCore(_ file: MarkdownFile?, state: inout State) -> Effect<Action> {
        state.selectedFileURL = file?.url
        Self.presenterContinuation?.yield(file?.url)
        state.hasUnsavedChanges = false
        state.currentFrontmatter = NoteFrontmatter()
        guard let file, !file.isDirectory else {
            state.editorContent = ""
            return .none
        }
        // If the file isn't downloaded yet, trigger download but don't try to load content
        guard file.isDownloaded else {
            state.editorContent = ""
            return .run { _ in
                try? MarkdownDocument.startDownloading(file)
            }
        }
        let store = syncStore
        return .run { send in
            let content = try MarkdownDocument.loadContent(of: file)
            // Record loaded content for future conflict detection
            let modDate = (try? file.url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date()
            store.record(relativePath: file.relativePath, content: content, modDate: modDate)
            await send(.fileContentLoaded(content))
        }
    }

      private static func appendSnippet(_ snippet: String, to content: String) -> String {
        guard !content.isEmpty else { return snippet }
        if content.hasSuffix("\n\n") {
            return content + snippet
        }
        if content.hasSuffix("\n") {
            return content + "\n" + snippet
        }
        return content + "\n\n" + snippet
      }

      private static func initialVaultSnapshot(at docsURL: URL) -> [String] {
        guard let enumerator = FileManager.default.enumerator(
            at: docsURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        let normalizedDocsPath = docsURL.resolvingSymlinksInPath().standardizedFileURL.path
        let normalizedDocsLower = normalizedDocsPath.lowercased()

        var files: [String] = []
        while let url = enumerator.nextObject() as? URL {
            let isDirectory = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            if isDirectory { continue }
            let ext = url.pathExtension.lowercased()
            if ext == "md" || ext == "markdown" || ext == "txt" {
                let normalizedPath = url.resolvingSymlinksInPath().standardizedFileURL.path
                let normalizedLower = normalizedPath.lowercased()
                let relative: String
                if normalizedLower.hasPrefix(normalizedDocsLower + "/") {
                    relative = String(normalizedPath.dropFirst(normalizedDocsPath.count + 1))
                } else {
                    relative = url.lastPathComponent
                }
                files.append(relative)
                if files.count >= 12 { break }
            }
          }
          return files
      }

      /// Creates the long-running file-watching effect with the current documents directory.
      private func startFileWatcher() -> Effect<Action> {
        .run { send in
            let docsURL = CloudContainerProvider.documentsDirectory()
            appSyncLogger.info(
                "Starting file watcher. docsPath=\(docsURL.path, privacy: .public)"
            )
            let snapshot = Self.initialVaultSnapshot(at: docsURL)
            if snapshot.isEmpty {
                appSyncLogger.info("Initial vault snapshot contains no markdown files")
            } else {
                appSyncLogger.info("Initial vault snapshot count=\(snapshot.count, privacy: .public) sample=\(snapshot.joined(separator: ", "), privacy: .public)")
            }

            let externalChanges = AsyncStream.makeStream(of: URL.self)
            let fileToPresent = AsyncStream.makeStream(of: URL?.self)
            Self.presenterContinuation = fileToPresent.continuation

            let stream = AsyncStream<([MarkdownFile], SyncSummary)> { continuation in
                let task = Task { @MainActor in
                    let watcher = FileWatcher(documentsURL: docsURL)
                    let presenter = DocumentPresenter()

                    presenter.onContentDidChange = { url in
                        externalChanges.continuation.yield(url)
                    }
                    presenter.onDidMove = { newURL in
                        externalChanges.continuation.yield(newURL)
                    }

                    // Consume file-to-present commands from the reducer
                    let presenterTask = Task { @MainActor in
                        for await url in fileToPresent.stream {
                            if let url {
                                presenter.present(url: url)
                            } else {
                                presenter.resign()
                            }
                        }
                    }

                    watcher.start()
                    defer {
                        _ = watcher
                        _ = presenter
                        presenterTask.cancel()
                    }

                    for await files in watcher.$files.values {
                        let summary = watcher.syncSummary
                        appSyncLogger.debug(
                            "Watcher update files=\(files.count, privacy: .public) conflicts=\(summary.conflictCount, privacy: .public)"
                        )
                        continuation.yield((files, summary))
                    }
                    continuation.finish()
                }

                continuation.onTermination = { _ in
                    appSyncLogger.info("File watcher stream terminated")
                    externalChanges.continuation.finish()
                    fileToPresent.continuation.finish()
                    task.cancel()
                }
            }

            await withTaskGroup(of: Void.self) { group in
                group.addTask {
                    var downloadedURLs: Set<URL> = []
                    for await (files, summary) in stream {
                        await send(.filesUpdated(files))
                        await send(.syncSummaryUpdated(summary))
                        for file in files where file.syncStatus == .notDownloaded {
                            guard !downloadedURLs.contains(file.url) else { continue }
                            downloadedURLs.insert(file.url)
                            try? MarkdownDocument.startDownloading(file)
                        }
                    }
                }
                group.addTask {
                    for await url in externalChanges.stream {
                        await send(.externalFileChange(url))
                    }
                }
            }
        }
        .cancellable(id: FileWatcherID.watcher, cancelInFlight: true)
    }
}
