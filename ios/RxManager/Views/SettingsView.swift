import SwiftUI

struct SettingsView: View {
    @Environment(MedStore.self) private var store

    private var version: String {
        let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let b = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(v) (\(b))"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                sectionHeader("Refill timing", "How early Rx Manager flags a medication for reorder.")
                card {
                    timingRow("Order lead time", "Reorder this many days before you'd run out.",
                              \.lead, 1...60)
                    divider
                    timingRow("Overdue threshold", "Flag as overdue once days on hand drops to this.",
                              \.ship, 0...30)
                    divider
                    timingRow("Renewal lead", "Extra lead time when a prescription has no refills left.",
                              \.renewLead, 1...90)
                    divider
                    timingRow("Controlled-substance buffer", "Added lead for scheduled medications.",
                              \.ctrlExtra, 0...30)
                    divider
                    timingRow("Cold-chain buffer", "Added lead for refrigerated medications.",
                              \.coldExtra, 0...30)
                }

                sectionHeader("Reminders", nil)
                card {
                    row("Text reminders", "Coming soon")
                }

                sectionHeader("About", nil)
                card {
                    row("Version", version)
                    divider
                    linkRow("Privacy Policy", "https://rxmanager.us/privacy.html")
                    divider
                    linkRow("Terms of Service", "https://rxmanager.us/terms.html")
                }

                Text("Rx Manager · rxmanager.us")
                    .font(.system(size: 12))
                    .foregroundStyle(RxTheme.muted)
                    .padding(.top, 6)

                Spacer(minLength: 20)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 28)
        }
        .background(RxTheme.bg)
        .scrollIndicators(.hidden)
    }

    // MARK: Rows

    private func timingRow(_ title: String, _ desc: String,
                           _ keyPath: WritableKeyPath<AppSettings, Double>,
                           _ range: ClosedRange<Double>) -> some View {
        let binding = Binding<Double>(
            get: { store.settings[keyPath: keyPath] },
            set: {
                var s = store.settings
                s[keyPath: keyPath] = $0
                store.updateSettings(s)
            }
        )
        return HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(RxTheme.ink)
                Text(desc)
                    .font(.system(size: 12))
                    .foregroundStyle(RxTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            VStack(spacing: 4) {
                Text("\(Int(binding.wrappedValue)) d")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(RxTheme.accent)
                    .monospacedDigit()
                Stepper("", value: binding, in: range, step: 1)
                    .labelsHidden()
            }
        }
        .padding(.vertical, 2)
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.system(size: 15)).foregroundStyle(RxTheme.ink)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(RxTheme.muted)
        }
        .padding(.vertical, 2)
    }

    private func linkRow(_ label: String, _ urlString: String) -> some View {
        Link(destination: URL(string: urlString)!) {
            HStack {
                Text(label).font(.system(size: 15)).foregroundStyle(RxTheme.ink)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(RxTheme.muted)
            }
            .padding(.vertical, 2)
            .contentShape(Rectangle())
        }
    }

    // MARK: Building blocks

    private func sectionHeader(_ title: String, _ subtitle: String?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(RxTheme.muted)
                .textCase(.uppercase)
            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(RxTheme.muted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 6)
    }

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(spacing: 10) { content() }
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(RxTheme.card, in: RoundedRectangle(cornerRadius: RxTheme.cardRadius))
            .shadow(color: RxTheme.cardShadow, radius: 10, y: 5)
    }

    private var divider: some View {
        Rectangle().fill(RxTheme.ink.opacity(0.06)).frame(height: 1)
    }
}
