import ComposableArchitecture
import MarkdownStorage
import SwiftUI

/// Flat note list sidebar, nvALT-style.
struct FileSidebar: View {
    @Bindable var store: StoreOf<AppFeature>

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Notes")
                    .font(Theme.monoBold)
                    .foregroundStyle(Theme.text)

                Text("\(store.filteredFiles.count)")
                    .font(Theme.monoXSmall)
                    .foregroundStyle(Theme.textMuted)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Theme.backgroundTertiary)

                // Sync status indicator
                SyncStatusBadge(summary: store.syncSummary)

                Spacer()

                #if os(macOS)
                Menu {
                    Button {
                        store.send(.setSortField(.updated))
                    } label: {
                        if store.sortField == .updated { Label("Updated", systemImage: "checkmark") }
                        else { Text("Updated") }
                    }
                    Button {
                        store.send(.setSortField(.created))
                    } label: {
                        if store.sortField == .created { Label("Created", systemImage: "checkmark") }
                        else { Text("Created") }
                    }
                    Button {
                        store.send(.setSortField(.name))
                    } label: {
                        if store.sortField == .name { Label("Name", systemImage: "checkmark") }
                        else { Text("Name") }
                    }
                    Divider()
                    Button {
                        store.send(.toggleSortDirection)
                    } label: {
                        Text(store.sortAscending ? "↑ Ascending" : "↓ Descending")
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                        .foregroundStyle(Theme.textDim)
                        .font(.system(size: 11))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background(Theme.backgroundTertiary)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .help("Sort by")

                Menu {
                    Button("Finder") { store.send(.openInApp("Finder")) }
                    Button("iTerm") { store.send(.openInApp("iTerm")) }
                    Button("Warp") { store.send(.openInApp("Warp")) }
                    Divider()
                    Button("Cursor") { store.send(.openInApp("Cursor")) }
                    Button("VS Code") { store.send(.openInApp("VS Code")) }
                    Divider()
                    Button("Copy Path") { store.send(.copyVaultPath) }
                } label: {
                    Image(systemName: "arrow.up.forward.app")
                        .foregroundStyle(Theme.textDim)
                        .font(.system(size: 12))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background(Theme.backgroundTertiary)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .help("Open in...")
                #endif
            }
            .padding(.trailing, 12)
            .padding(.leading, 12)
            .padding(.vertical, 6)

            Divider().background(Theme.border)

            // Flat note list
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(store.filteredFiles) { file in
                        NoteRow(file: file, store: store)
                    }
                }
                .padding(.vertical, 4)
            }

            Spacer()
        }
        .background(Theme.backgroundSecondary)
    }
}

// MARK: - Sync Status Badge

private struct SyncStatusBadge: View {
    let summary: SyncSummary

    var body: some View {
        if !summary.statusText.isEmpty && !summary.isSynced {
            HStack(spacing: 3) {
                if summary.conflictCount > 0 {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(.orange)
                } else {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 8))
                        .foregroundStyle(Theme.textMuted)
                }
                Text(summary.statusText)
                    .font(.custom("MonaspiceNeNFM-Regular", size: 8))
                    .foregroundStyle(Theme.textMuted)
                    .lineLimit(1)
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(Theme.backgroundTertiary)
            .fixedSize()
        }
    }
}

// MARK: - Note Row

private struct NoteRow: View {
    let file: MarkdownFile
    let store: StoreOf<AppFeature>

    private var isSelected: Bool {
        store.selectedFileURL == file.url
    }

    var body: some View {
        Button {
            Haptics.play(.selection)
            store.send(.selectFile(file))
        } label: {
            HStack(alignment: .top, spacing: 8) {
                // Emoji icon or default
                if let icon = file.icon, !icon.isEmpty {
                    Text(icon)
                        .font(.system(size: 13))
                        .frame(width: 18, alignment: .center)
                        .padding(.top, 1)
                } else {
                    fileStatusIcon
                        .frame(width: 18, alignment: .center)
                        .padding(.top, 2)
                }

                VStack(alignment: .leading, spacing: 2) {
                    // Title
                    Text(file.title)
                        .font(Theme.monoSmall)
                        .foregroundStyle(isSelected ? Theme.text : Theme.textDim)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    // Tags
                    if !file.tags.isEmpty {
                        Text(file.tags.joined(separator: " "))
                            .font(.custom("MonaspiceNeNFM-Regular", size: 8))
                            .foregroundStyle(Theme.textMuted)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }

                Spacer()

                // Conflict warning icon
                if file.hasConflict {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                        .font(.system(size: 10))
                        .padding(.top, 2)
                }

                // Relative time
                if let lastModified = file.lastModified {
                    Text(RelativeTime.string(from: lastModified))
                        .font(.custom("MonaspiceNeNFM-Regular", size: 9))
                        .foregroundStyle(Theme.textMuted)
                        .padding(.top, 1)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? Theme.selection : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Rename") { Haptics.play(.light); store.send(.startRenameFile(file)) }
            Button("Delete", role: .destructive) { Haptics.play(.warning); store.send(.deleteFile(file)) }
        }
    }

    @ViewBuilder
    private var fileStatusIcon: some View {
        if file.syncStatus == .notDownloaded {
            Image(systemName: "icloud.and.arrow.down")
                .foregroundStyle(Theme.textMuted)
                .font(.system(size: 11))
        } else {
            Image(systemName: "doc.text")
                .foregroundStyle(isSelected ? Theme.accent : Theme.textDim)
                .font(.system(size: 11))
        }
    }
}
