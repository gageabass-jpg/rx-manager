import SwiftUI

struct MedListView: View {
    @Environment(MedStore.self) private var store

    private var sortedMeds: [Medication] {
        store.activeMeds.sorted {
            store.metrics(for: $0).daysOnHand < store.metrics(for: $1).daysOnHand
        }
    }

    private var todayLabel: String {
        let f = DateFormatter()
        f.dateFormat = "dd MMM yyyy"
        return f.string(from: Date()).uppercased()
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(sortedMeds) { med in
                        MedRow(med: med, metrics: store.metrics(for: med))
                        Divider().overlay(RxColor.line)
                    }
                }
                .background(RxColor.card)
            }
            .background(RxColor.paper)
            .navigationTitle("Rx Manager")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(RxColor.ink, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .safeAreaInset(edge: .top, spacing: 0) { summaryBar }
        }
    }

    private var summaryBar: some View {
        HStack(spacing: 10) {
            Text(todayLabel)
            Text("·")
            Text("\(store.activeMeds.count) ACTIVE")
            Text("·")
            Text("\(store.needActionCount) NEED ACTION")
                .foregroundStyle(store.needActionCount > 0 ? RxColor.red : .white.opacity(0.7))
            Spacer()
        }
        .font(.system(size: 12, weight: .semibold, design: .monospaced))
        .foregroundStyle(.white.opacity(0.82))
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .frame(maxWidth: .infinity)
        .background(RxColor.ink)
    }
}

struct MedRow: View {
    let med: Medication
    let metrics: MedMetrics

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(med.generic)
                        .font(.system(size: 19, weight: .bold))
                        .foregroundStyle(RxColor.ink)
                    if !med.brand.isEmpty {
                        Text("(\(med.brand))")
                            .font(.system(size: 17))
                            .foregroundStyle(RxColor.muted)
                    }
                }
                Text("\(med.strength) · \(med.sig)")
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(RxColor.ink.opacity(0.85))
                if !med.drugClass.isEmpty {
                    Text(med.drugClass.uppercased())
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(RxColor.muted)
                        .lineLimit(1)
                }
                if !metrics.tag.isEmpty {
                    Text(metrics.tag)
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .background(RxColor.rank(metrics.rank), in: Capsule())
                        .padding(.top, 2)
                }
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 0) {
                Text("\(metrics.daysOnHand)")
                    .font(.system(size: 34, weight: .semibold, design: .monospaced))
                    .foregroundStyle(metrics.needsAction ? RxColor.rank(metrics.rank) : RxColor.ink)
                Text("DAYS")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(RxColor.muted)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(RxColor.card)
    }
}
