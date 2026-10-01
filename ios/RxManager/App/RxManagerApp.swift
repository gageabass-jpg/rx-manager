import SwiftUI

@main
struct RxManagerApp: App {
    @State private var store = MedStore()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environment(store)
                .preferredColorScheme(.light)
        }
    }
}
