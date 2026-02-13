#if os(iOS)
import ComposableArchitecture
import MarkdownStorage
import SwiftUI

/// Shown on iOS first launch when iCloud is signed in but no vault folder is selected.
/// Guides the user to pick the Hashy folder in iCloud Drive for cross-device sync.
struct VaultSetupSheet: View {
    let store: StoreOf<AppFeature>
    @State private var showPicker = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "icloud")
                    .font(.system(size: 48))
                    .foregroundStyle(Theme.accent)

                Text("Set Up iCloud Sync")
                    .font(Theme.monoBold)
                    .foregroundStyle(Theme.text)

                Text("To sync notes between devices, select your Hashy folder in iCloud Drive.\n\nOpen iCloud Drive and pick the \"Hashy\" folder (create it if it doesn't exist).")
                    .font(Theme.monoSmall)
                    .foregroundStyle(Theme.textDim)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Button {
                    Haptics.play(.light)
                    showPicker = true
                } label: {
                    Text("Choose iCloud Drive Folder")
                        .font(Theme.monoSmall)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Theme.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                Button("Skip for Now") {
                    Haptics.play(.light)
                    store.send(.dismissVaultSetup(false))
                }
                .font(Theme.monoXSmall)
                .foregroundStyle(Theme.textDim)

                Spacer()
            }
            .frame(maxWidth: .infinity)
            .background(Theme.background)
            .sheet(isPresented: $showPicker) {
                FolderPickerView { url in
                    store.send(.vaultFolderChosen(url))
                    showPicker = false
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}
#endif
