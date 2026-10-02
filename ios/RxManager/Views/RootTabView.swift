import SwiftUI

struct RootTabView: View {
    var body: some View {
        TabView {
            NavigationStack {
                MedListView()
            }
            .tabItem { Label("Meds", systemImage: "pills") }

            NavigationStack {
                ComingSoonView(icon: "camera.viewfinder",
                               title: "Scan a label",
                               note: "Point your camera at a prescription label to add or refill a medication.")
                    .navigationTitle("Scan")
            }
            .tabItem { Label("Scan", systemImage: "camera.viewfinder") }

            NavigationStack {
                AccountView()
                    .navigationTitle("Account")
            }
            .tabItem { Label("Account", systemImage: "person.crop.circle") }

            NavigationStack {
                ComingSoonView(icon: "gearshape",
                               title: "Settings",
                               note: "Reminder lead times and preferences.")
                    .navigationTitle("Settings")
            }
            .tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .tint(RxTheme.accent)
    }
}

struct ComingSoonView: View {
    let icon: String
    let title: String
    let note: String

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 46, weight: .light))
                .foregroundStyle(RxTheme.accent)
            Text(title)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(RxTheme.ink)
            Text(note)
                .font(.system(size: 14))
                .foregroundStyle(RxTheme.muted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 44)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(RxTheme.bg)
    }
}
