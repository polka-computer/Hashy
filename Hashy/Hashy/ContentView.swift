import AppFeature
import ComposableArchitecture
import SwiftUI

struct ContentView: View {
    var body: some View {
        HashyMainView(store: HashyApp.store)
            .preferredColorScheme(HashyApp.store.isDarkMode ? .dark : .light)
    }
}
