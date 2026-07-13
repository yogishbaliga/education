import SwiftUI

@main
struct PhotoLibrarySyncApp: App {
    @StateObject private var engine = SyncEngine()

    var body: some Scene {
        WindowGroup("Photo Library Sync") {
            ContentView()
                .environmentObject(engine)
                .frame(minWidth: 820, minHeight: 620)
        }
        .windowStyle(.titleBar)
    }
}
