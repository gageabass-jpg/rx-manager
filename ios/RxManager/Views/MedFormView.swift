import SwiftUI

enum MedFormMode {
    case add
    case edit(Medication)
}

struct MedFormView: View {
    @Environment(MedStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let mode: MedFormMode
    @State private var draft: Medication
    @State private var error: String?
    @State private var searching = false

    init(mode: MedFormMode) {
        self.mode = mode
        switch mode {
        case .add:
            _draft = State(initialValue: Medication(filled: MedStore.todayString()))
        case .edit(let m):
            _draft = State(initialValue: m)
        }
    }

    private var isAdd: Bool { if case .add = mode { return true }; return false }

    private var filledDate: Binding<Date> {
        Binding(
            get: { MedStore.parseDate(draft.filled) ?? Date() },
            set: { draft.filled = MedStore.dateString($0) }
        )
    }

    /// String proxy for quantity so the field is blank (not "0") until typed,
    /// and digits replace rather than append to a leading zero.
    private var qtyText: Binding<String> {
        Binding(
            get: { draft.qty > 0 ? String(Int(draft.qty)) : "" },
            set: { draft.qty = Double($0.filter(\.isNumber)) ?? 0 }
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                if let error {
                    Text(error)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color(hex: 0xb42318))
                        .listRowBackground(Color(hex: 0xfbeae8))
                }

                Section {
                    Button { searching = true } label: {
                        Label("Look up a medication", systemImage: "magnifyingglass")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(RxTheme.accent)
                    }
                } footer: {
                    Text("Search the U.S. medication database to fill in the name, strength, and form automatically.")
                }

                Section("Identity") {
                    TextField("Generic name", text: $draft.generic)
                        .textInputAutocapitalization(.never)
                    TextField("Brand (optional)", text: $draft.brand)
                    TextField("Strength — e.g. 25 mg", text: $draft.strength)
                        .textInputAutocapitalization(.never)
                    TextField("Drug class (optional)", text: $draft.drugClass)
                    TextField("Used for (optional)", text: $draft.indication)
                }

                Section("Dosing") {
                    TextField("Sig — e.g. 1 tab PO BID", text: $draft.sig)
                    Stepper("Doses per day: \(Int(draft.dosesPerDay))",
                            value: $draft.dosesPerDay, in: 1...12, step: 1)
                }

                Section("Supply") {
                    HStack {
                        Text("Quantity dispensed")
                        Spacer()
                        TextField("90", text: qtyText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 90)
                    }
                    DatePicker("Fill date", selection: filledDate, displayedComponents: .date)
                    Stepper("Refills remaining: \(draft.refills)",
                            value: $draft.refills, in: 0...99, step: 1)
                }

                Section("Prescriber & pharmacy") {
                    TextField("Prescriber (optional)", text: $draft.prescriber)
                    TextField("Pharmacy (optional)", text: $draft.pharmacy)
                    TextField("Rx number (optional)", text: $draft.rx)
                }

                Section("Notes") {
                    TextField("Anything to remember", text: $draft.notes, axis: .vertical)
                        .lineLimit(2...5)
                }
            }
            .navigationTitle(isAdd ? "Add medication" : "Edit medication")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { trySave() }.fontWeight(.semibold)
                }
            }
            .tint(RxTheme.accent)
            .sheet(isPresented: $searching) {
                MedSearchView { hit in apply(hit) }
            }
        }
    }

    /// Fill identity fields from a search result, then fetch its drug class.
    private func apply(_ hit: DrugHit) {
        draft.generic = hit.generic
        if !hit.brand.isEmpty { draft.brand = hit.brand }
        if !hit.strength.isEmpty { draft.strength = hit.strength }
        if !hit.form.isEmpty { draft.form = hit.form }
        error = nil

        Task {
            if let cls = try? await RxNormService.drugClass(rxcui: hit.rxcui) {
                await MainActor.run {
                    if draft.drugClass.trimmingCharacters(in: .whitespaces).isEmpty {
                        draft.drugClass = cls
                    }
                }
            }
        }
    }

    private func trySave() {
        let g = draft.generic.trimmingCharacters(in: .whitespaces)
        let s = draft.strength.trimmingCharacters(in: .whitespaces)
        if g.isEmpty { error = "Enter a generic name."; return }
        if s.range(of: #"\d\s*(mg|mcg|meq|ml|unit|units|g|%)"#, options: [.regularExpression, .caseInsensitive]) == nil {
            error = "Strength needs a unit — mg, mcg, mEq, mL, units."
            return
        }
        if draft.sig.trimmingCharacters(in: .whitespaces).isEmpty { error = "Enter the sig (directions)."; return }
        if draft.dosesPerDay <= 0 { error = "Doses per day must be at least 1."; return }
        if draft.qty <= 0 { error = "Quantity dispensed must be greater than 0."; return }

        draft.generic = g
        draft.strength = s
        store.upsert(draft)
        dismiss()
    }
}
