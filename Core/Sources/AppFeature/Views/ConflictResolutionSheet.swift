import ComposableArchitecture
import MarkdownStorage
import SwiftUI

/// Modal sheet for user-driven conflict resolution.
struct ConflictResolutionSheet: View {
    let conflict: FileConflict
    let store: StoreOf<AppFeature>

    private var conflictVersion: ConflictVersion? {
        conflict.conflictVersions.first
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .font(.system(size: 20))
                Text("Sync Conflict")
                    .font(Theme.monoBold)
                    .foregroundStyle(Theme.text)
            }

            Text("This file was modified on another device while you were editing it.")
                .font(Theme.monoSmall)
                .foregroundStyle(Theme.textDim)

            Divider().background(Theme.border)

            // Current version
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Your Version")
                        .font(Theme.monoSmall)
                        .foregroundStyle(Theme.text)
                    Spacer()
                    Text(Self.dateFormatter.string(from: conflict.currentModDate))
                        .font(.custom("MonaspiceNeNFM-Regular", size: 9))
                        .foregroundStyle(Theme.textMuted)
                }

                Text(previewLines(conflict.currentContent))
                    .font(.custom("MonaspiceNeNFM-Regular", size: 10))
                    .foregroundStyle(Theme.textDim)
                    .lineLimit(8)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.backgroundTertiary)
            }

            // Conflict version
            if let version = conflictVersion {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Their Version")
                                .font(Theme.monoSmall)
                                .foregroundStyle(Theme.text)
                            if let device = version.originDeviceName {
                                Text("From: \(device)")
                                    .font(.custom("MonaspiceNeNFM-Regular", size: 9))
                                    .foregroundStyle(Theme.textMuted)
                            }
                        }
                        Spacer()
                        Text(Self.dateFormatter.string(from: version.modificationDate))
                            .font(.custom("MonaspiceNeNFM-Regular", size: 9))
                            .foregroundStyle(Theme.textMuted)
                    }

                    Text(previewLines(version.content))
                        .font(.custom("MonaspiceNeNFM-Regular", size: 10))
                        .foregroundStyle(Theme.textDim)
                        .lineLimit(8)
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Theme.backgroundTertiary)
                }
            }

            Divider().background(Theme.border)

            // Action buttons
            HStack(spacing: 12) {
                Button("Keep Mine") {
                    store.send(.resolveConflict(.keepCurrent))
                }
                .font(Theme.monoSmall)

                if let version = conflictVersion {
                    Button("Keep Theirs") {
                        store.send(.resolveConflict(.keepOther(version.id)))
                    }
                    .font(Theme.monoSmall)
                }

                Button("Keep Both") {
                    store.send(.resolveConflict(.keepBoth))
                }
                .font(Theme.monoSmall)

                Spacer()
            }
        }
        .padding(20)
        .frame(width: 480)
        .background(Theme.backgroundSecondary)
    }

    private func previewLines(_ content: String) -> String {
        let lines = content.components(separatedBy: "\n")
        let preview = lines.prefix(10).joined(separator: "\n")
        if lines.count > 10 {
            return preview + "\n..."
        }
        return preview
    }
}
