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

    private static let day: TimeInterval = 86_400

    private var fileURL: URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("rxmanager.json")
    }

    init() { load() }

    // MARK: Persistence

    private struct PersistState: Codable { var meds: [Medication]; var settings: AppSettings }

    func load() {
        if let data = try? Data(contentsOf: fileURL),
           let state = try? JSONDecoder().decode(PersistState.self, from: data) {
            meds = state.meds
            settings = state.settings
        } else {
            meds = MedStore.seed()
            save()
        }
    }

    func save() {
        let state = PersistState(meds: meds, settings: settings)
        if let data = try? JSONEncoder().encode(state) {
            try? data.write(to: fileURL, options: .atomic)
        }
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

    static func todayString() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f.string(from: Date())
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
