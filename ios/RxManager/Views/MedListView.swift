import SwiftUI

struct MedListView: View {
    @Environment(MedStore.self) private var store

    private var sortedMeds: [Medication] {
        store.activeMeds.sorted {
            store.metrics(for: $0).daysOnHand < store.metrics(for: $1).daysOnHand
        }
    }

    private var greeting: String {
        let h = Calendar.current.component(.hour, from: Date())
        switch h {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        default: return "Good evening"
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 13) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(greeting)
                        .font(.system(size: 13))
                        .foregroundStyle(RxTheme.muted)
                    Text("Your medications")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(RxTheme.ink)
                }
                .padding(.top, 10)
                .padding(.bottom, 2)

                if store.needActionCount > 0 {
                    Text("\(store.needActionCount) need\(store.needActionCount == 1 ? "s" : "") attention")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color(hex: 0xb54708))
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(hex: 0xfbeadd), in: RoundedRectangle(cornerRadius: 12))
                }

                ForEach(sortedMeds) { med in
                    MedCard(med: med, metrics: store.metrics(for: med))
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 28)
        }
        .background(RxTheme.bg)
        .scrollIndicators(.hidden)
    }
}

struct MedCard: View {
    let med: Medication
    let metrics: MedMetrics

    var body: some View {
        let s = RxTheme.status(rank: metrics.rank, renewal: metrics.renewal)
        HStack(spacing: 13) {
            ZStack {
                Circle().fill(s.tint)
                VStack(spacing: -1) {
                    Text("\(metrics.daysOnHand)")
                        .font(.system(size: 17, weight: .heavy, design: .rounded))
                    Text("days")
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                }
                .foregroundStyle(s.fg)
            }
            .frame(width: 52, height: 52)

            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text(med.generic)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(RxTheme.ink)
                    if !med.brand.isEmpty {
                        Text(med.brand)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(RxTheme.muted)
                    }
                }
                Text("\(med.strength) · \(RxTheme.frequency(med.dosesPerDay))")
                    .font(.system(size: 12))
                    .foregroundStyle(RxTheme.muted)
                if let label = s.label {
                    Text(label)
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundStyle(s.fg)
                        .padding(.horizontal, 8).padding(.vertical, 2)
                        .background(s.tint, in: Capsule())
                        .padding(.top, 2)
                }
            }
            Spacer(minLength: 4)
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(RxTheme.muted.opacity(0.5))
        }
        .padding(14)
        .background(RxTheme.card, in: RoundedRectangle(cornerRadius: RxTheme.cardRadius))
        .shadow(color: RxTheme.cardShadow, radius: 10, y: 5)
    }
}
