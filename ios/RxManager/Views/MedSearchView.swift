import SwiftUI

/// Search the RxNorm database and pick a product to pre-fill the add/edit form.
struct MedSearchView: View {
    @Environment(\.dismiss) private var dismiss
    let onPick: (DrugHit) -> Void

    @State private var query = ""
    @State private var hits: [DrugHit] = []
    @State private var loading = false
    @State private var message: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                GooeyInput(text: $query,
                           placeholder: "Search",
                           expandedPlaceholder: "Generic or brand name",
                           autoOpen: true)
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    .padding(.bottom, 14)

                List {
                    if loading {
                        HStack(spacing: 10) {
                            ProgressView()
                            Text("Searching…").foregroundStyle(RxTheme.muted)
                        }
                    }

                    if let message {
                        Text(message)
                            .font(.system(size: 14))
                            .foregroundStyle(RxTheme.muted)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    ForEach(hits) { hit in
                        Button { onPick(hit); dismiss() } label: { row(hit) }
                            .buttonStyle(.plain)
                    }
                }
                .listStyle(.plain)
            }
            .background(RxTheme.bg)
            .navigationTitle("Find a medication")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .task(id: query) { await run() }
        }
    }

    private func row(_ hit: DrugHit) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(hit.generic.isEmpty ? hit.fullName : hit.generic)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(RxTheme.ink)
                    if !hit.brand.isEmpty {
                        Text(hit.brand)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(RxTheme.muted)
                    }
                }
                Text([hit.strength, hit.form].filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.system(size: 13))
                    .foregroundStyle(RxTheme.muted)
            }
            Spacer(minLength: 6)
            Text(hit.isBranded ? "brand" : "generic")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(hit.isBranded ? Color(hex: 0x534ab7) : Color(hex: 0x1d9e75))
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background((hit.isBranded ? Color(hex: 0xececfb) : Color(hex: 0xe3f3ee)), in: Capsule())
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    private func run() async {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard q.count >= 2 else {
            hits = []; message = "Type a medication name to search."; loading = false
            return
        }
        // Debounce: this task is cancelled and restarted on each keystroke.
        try? await Task.sleep(nanoseconds: 350_000_000)
        if Task.isCancelled { return }

        loading = true; message = nil
        do {
            let results = try await RxNormService.search(q)
            if Task.isCancelled { return }
            hits = results
            message = results.isEmpty ? "No matches. Check the spelling, or add it manually." : nil
        } catch {
            if Task.isCancelled { return }
            hits = []
            message = "Couldn’t reach the medication database. You can still add it manually."
        }
        loading = false
    }
}
