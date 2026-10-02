import SwiftUI

struct MedDetailView: View {
    @Environment(MedStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let medID: String
    @State private var editing = false
    @State private var confirmDelete = false

    var body: some View {
        if let med = store.med(id: medID) {
            content(med)
        } else {
            // Med was deleted — fall back out of the detail screen.
            RxTheme.bg.onAppear { dismiss() }
        }
    }

    @ViewBuilder
    private func content(_ med: Medication) -> some View {
        let m = store.metrics(for: med)
        let s = RxTheme.status(rank: m.rank, renewal: m.renewal)

        ScrollView {
            VStack(spacing: 16) {
                header(med, m, s)
                supplyCard(med, m)
                factsCard(med)
                if !med.notes.isEmpty { notesCard(med) }
                actions(med)
                if !med.history.isEmpty { historyCard(med) }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .background(RxTheme.bg)
        .scrollIndicators(.hidden)
        .navigationTitle(med.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") { editing = true }.tint(RxTheme.accent)
            }
        }
        .sheet(isPresented: $editing) {
            MedFormView(mode: .edit(med)).environment(store)
        }
        .confirmationDialog("Delete this medication?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) { store.delete(med.id); dismiss() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes \(med.displayName) and its history from this device.")
        }
    }

    // MARK: Pieces

    private func header(_ med: Medication, _ m: MedMetrics, _ s: RxTheme.Status) -> some View {
        VStack(spacing: 12) {
            ZStack {
                Circle().stroke(s.tint, lineWidth: 10)
                VStack(spacing: -2) {
                    Text("\(m.daysOnHand)")
                        .font(.system(size: 40, weight: .heavy, design: .rounded))
                    Text("days on hand")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                }
                .foregroundStyle(s.fg)
            }
            .frame(width: 128, height: 128)

            VStack(spacing: 3) {
                Text(med.generic)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(RxTheme.ink)
                Text("\(med.strength) · \(RxTheme.frequency(med.dosesPerDay))")
                    .font(.system(size: 14))
                    .foregroundStyle(RxTheme.muted)
            }

            if let label = s.label {
                Text(label)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(s.fg)
                    .padding(.horizontal, 12).padding(.vertical, 5)
                    .background(s.tint, in: Capsule())
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    private func supplyCard(_ med: Medication, _ m: MedMetrics) -> some View {
        card {
            row("Remaining", "\(Int(m.remaining)) doses")
            divider
            row("Order by", dateLabel(m.orderBy))
            divider
            row("Refills left", "\(med.refills)")
            divider
            row("Last filled", med.filled)
        }
    }

    private func factsCard(_ med: Medication) -> some View {
        card {
            if !med.brand.isEmpty { row("Brand", med.brand); divider }
            if !med.drugClass.isEmpty { row("Class", med.drugClass); divider }
            if !med.indication.isEmpty { row("Used for", med.indication); divider }
            row("Sig", med.sig)
            if !med.prescriber.isEmpty { divider; row("Prescriber", med.prescriber) }
            if !med.pharmacy.isEmpty { divider; row("Pharmacy", med.pharmacy) }
            if !med.rx.isEmpty { divider; row("Rx #", med.rx) }
        }
    }

    private func notesCard(_ med: Medication) -> some View {
        card {
            VStack(alignment: .leading, spacing: 4) {
                Text("Notes")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(RxTheme.muted)
                Text(med.notes)
                    .font(.system(size: 14))
                    .foregroundStyle(RxTheme.ink)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func actions(_ med: Medication) -> some View {
        VStack(spacing: 10) {
            Button { store.markRefilled(med.id) } label: {
                Label("Mark refilled today", systemImage: "arrow.clockwise")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(RxTheme.accent, in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(.white)
            }

            HStack(spacing: 10) {
                Button { store.setActive(med.id, !med.isActive) } label: {
                    Text(med.isActive ? "Deactivate" : "Reactivate")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(RxTheme.card, in: RoundedRectangle(cornerRadius: 14))
                        .foregroundStyle(RxTheme.ink)
                }
                Button(role: .destructive) { confirmDelete = true } label: {
                    Text("Delete")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(RxTheme.card, in: RoundedRectangle(cornerRadius: 14))
                        .foregroundStyle(Color(hex: 0xb42318))
                }
            }
        }
    }

    private func historyCard(_ med: Medication) -> some View {
        card {
            VStack(alignment: .leading, spacing: 9) {
                Text("History")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(RxTheme.muted)
                ForEach(Array(med.history.enumerated()), id: \.offset) { _, h in
                    HStack(alignment: .top, spacing: 8) {
                        Text(h.date)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(RxTheme.muted)
                            .frame(width: 84, alignment: .leading)
                        Text(h.event)
                            .font(.system(size: 13))
                            .foregroundStyle(RxTheme.ink)
                        Spacer(minLength: 0)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: Building blocks

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(spacing: 10) { content() }
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(RxTheme.card, in: RoundedRectangle(cornerRadius: RxTheme.cardRadius))
            .shadow(color: RxTheme.cardShadow, radius: 10, y: 5)
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.system(size: 14))
                .foregroundStyle(RxTheme.muted)
            Spacer(minLength: 12)
            Text(value)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(RxTheme.ink)
                .multilineTextAlignment(.trailing)
        }
    }

    private var divider: some View {
        Rectangle().fill(RxTheme.ink.opacity(0.06)).frame(height: 1)
    }

    private func dateLabel(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f.string(from: d)
    }
}
