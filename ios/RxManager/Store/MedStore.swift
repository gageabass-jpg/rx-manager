import Foundation
import Observation

/// Supply/timing metrics for a medication. Ported from the web app's calc().
struct MedMetrics {
    var remaining: Double
    var daysOnHand: Int
    var orderBy: Date
    var renewal: Bool
    var tag: String      // "", "OUT", "OVERDUE", "RENEW NOW", "ORDER NOW", "0 RF"
    var rank: Int        // 0 ok … 5 out (higher = needs attention)
    var needsAction: Bool { rank >= 2 }
}

@Observable
final class MedStore {
    var meds: [Medication] = []
    var settings = AppSettings()
    /// When the local data last changed — drives last-write-wins sync.
    private(set) var updatedAt: Date = Date()

    /// Called after a local mutation so the sync layer can push. Not persisted.
    @ObservationIgnored var onChange: (() -> Void)?

    private static let day: TimeInterval = 86_400

    private var fileURL: URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("rxmanager.json")
    }

    init() { load() }

    // MARK: Persistence

    private struct PersistState: Codable {
        var meds: [Medication]
        var settings: AppSettings
        var updatedAt: Date?
    }

    func load() {
        if let data = try? Data(contentsOf: fileURL),
           let state = try? JSONDecoder().decode(PersistState.self, from: data) {
            meds = state.meds
            settings = state.settings
            updatedAt = state.updatedAt ?? Date()
        } else {
            meds = MedStore.seed()
            save()
        }
    }

    func save() {
        let state = PersistState(meds: meds, settings: settings, updatedAt: updatedAt)
        if let data = try? JSONEncoder().encode(state) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }

    /// Record a local change: bump the timestamp, persist, and notify the sync layer.
    private func touch() {
        updatedAt = Date()
        save()
        onChange?()
    }

    /// Replace local data with a remote snapshot without marking it dirty (no push-back).
    func adopt(meds: [Medication], settings: AppSettings, updatedAt: Date) {
        self.meds = meds
        self.settings = settings
        self.updatedAt = updatedAt
        save()
    }

    // MARK: Derived data

    func metrics(for m: Medication) -> MedMetrics {
        let today = Calendar.current.startOfDay(for: Date())
        let dpd = max(0.01, m.dosesPerDay)
        let filled = MedStore.parseDate(m.filled) ?? today
        let elapsed = max(0, (today.timeIntervalSince(filled) / MedStore.day).rounded())
        let remaining = max(0, m.qty - elapsed * dpd)
        let doh = Int((remaining / dpd).rounded(.down))
        let runOut = today.addingTimeInterval(Double(doh) * MedStore.day)
        let renewal = m.refills <= 0
        let extra = (m.schedule.isEmpty ? 0 : settings.ctrlExtra) + (m.cold ? settings.coldExtra : 0)
        let lead = (renewal ? max(settings.lead, settings.renewLead) : settings.lead) + extra
        let orderBy = runOut.addingTimeInterval(-lead * MedStore.day)
        let dto = (orderBy.timeIntervalSince(today) / MedStore.day).rounded()

        var tag = ""; var rank = 0
        if doh <= 0 { tag = "OUT"; rank = 5 }
        else if Double(doh) <= settings.ship { tag = renewal ? "OVERDUE · RENEW" : "OVERDUE"; rank = 4 }
        else if renewal && dto <= 0 { tag = "RENEW NOW"; rank = 3 }
        else if !renewal && dto <= 0 { tag = "ORDER NOW"; rank = 2 }
        else if renewal { tag = "0 RF"; rank = 1 }

        return MedMetrics(remaining: remaining, daysOnHand: doh, orderBy: orderBy,
                          renewal: renewal, tag: tag, rank: rank)
    }

    var activeMeds: [Medication] { meds.filter { $0.isActive } }
    var needActionCount: Int { activeMeds.filter { metrics(for: $0).needsAction }.count }

    // MARK: Helpers

    static func parseDate(_ s: String) -> Date? {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f.date(from: s)
    }

    static func todayString() -> String { dateString(Date()) }

    static func dateString(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f.string(from: d)
    }

    func med(id: String) -> Medication? { meds.first { $0.id == id } }

    // MARK: Mutations

    /// Add a new medication or replace an existing one (matched by id).
    func upsert(_ med: Medication) {
        if let i = meds.firstIndex(where: { $0.id == med.id }) {
            meds[i] = med
        } else {
            var m = med
            m.history.insert(HistoryEntry(date: m.filled, event: "Added — qty \(Int(m.qty))"), at: 0)
            meds.append(m)
        }
        touch()
    }

    /// Record a refill: reset the fill date to today and decrement refills.
    func markRefilled(_ id: String) {
        guard let i = meds.firstIndex(where: { $0.id == id }) else { return }
        meds[i].filled = MedStore.todayString()
        meds[i].refills = max(0, meds[i].refills - 1)
        meds[i].history.insert(
            HistoryEntry(date: meds[i].filled,
                         event: "Filled — qty \(Int(meds[i].qty)) · \(meds[i].refills) refills left"),
            at: 0)
        touch()
    }

    func setActive(_ id: String, _ active: Bool) {
        guard let i = meds.firstIndex(where: { $0.id == id }) else { return }
        meds[i].status = active ? "active" : "inactive"
        meds[i].history.insert(
            HistoryEntry(date: MedStore.todayString(), event: "Status → \(active ? "ACTIVE" : "INACTIVE")"),
            at: 0)
        touch()
    }

    func delete(_ id: String) {
        meds.removeAll { $0.id == id }
        touch()
    }

    func updateSettings(_ newSettings: AppSettings) {
        settings = newSettings
        touch()
    }

    // MARK: Seed

    static func seed() -> [Medication] {
        let t = todayString()
        return [
            Medication(generic: "carvedilol", brand: "Coreg", strength: "25 mg",
                       drugClass: "Non-selective β-blocker w/ α₁ blockade", indication: "HFrEF",
                       sig: "1 tab PO BID with food", dosesPerDay: 2, qty: 64, filled: t,
                       refills: 0, prescriber: "Nguyen, T. — Cardiology", rx: "2718304",
                       notes: "Bottles on hand: A32."),
            Medication(generic: "cetirizine", brand: "Zyrtec", strength: "10 mg",
                       drugClass: "2nd-gen H₁ antagonist", indication: "Allergic rhinitis",
                       sig: "3 tabs (30 mg) PO daily", dosesPerDay: 3, qty: 156, filled: t,
                       refills: 2, prescriber: "Ortiz, M. — Primary Care", rx: "2718311"),
            Medication(generic: "ivabradine", brand: "Corlanor", strength: "5 mg",
                       drugClass: "Iƒ (HCN) channel inhibitor", indication: "HFrEF",
                       sig: "1 tab PO BID", dosesPerDay: 2, qty: 164, filled: t,
                       refills: 0, prescriber: "Nguyen, T. — Cardiology", rx: "2718305",
                       notes: "Non-formulary — renewal via cardiology."),
            Medication(generic: "empagliflozin", brand: "Jardiance", strength: "10 mg",
                       drugClass: "SGLT2 inhibitor", indication: "HFrEF",
                       sig: "1 tab PO QAM", dosesPerDay: 1, qty: 90, filled: t,
                       refills: 3, prescriber: "Nguyen, T. — Cardiology", rx: "2718306")
        ]
    }
}
