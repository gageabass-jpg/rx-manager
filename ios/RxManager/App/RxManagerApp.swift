import SwiftUI

@main
struct RxManagerApp: App {
    @State private var store: MedStore
    @State private var auth: AuthStore
    @State private var sync: SyncService
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let store = MedStore()
        let auth = AuthStore()
        _store = State(initialValue: store)
        _auth = State(initialValue: auth)
        _sync = State(initialValue: SyncService(meds: store, auth: auth))
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environment(store)
                .environment(auth)
                .environment(sync)
                .preferredColorScheme(.light)
                .task { await sync.syncNow() }
                .onChange(of: auth.isSignedIn) { _, signedIn in
                    Task {
                        if signedIn { await sync.syncNow() } else { sync.handleSignOut() }
                    }
                }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { Task { await sync.syncNow() } }
                }
        }
    }
}
