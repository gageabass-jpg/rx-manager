import SwiftUI

@main
struct RxManagerApp: App {
    @State private var store = MedStore()
    @State private var auth = AuthStore()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environment(store)
                .environment(auth)
                .preferredColorScheme(.light)
        }
    }
}
