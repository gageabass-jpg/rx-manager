import Foundation

struct HistoryEntry: Codable, Hashable {
    var date: String
    var event: String
}

/// One medication. Field names and semantics mirror the Rx Manager web app so
/// the same Supabase backend (rx-sync / rx-notify) can read the synced list.
struct Medication: Identifiable, Codable, Hashable {
    var id: String = UUID().uuidString
    var generic: String = ""
    var brand: String = ""
    var strength: String = ""
    var form: String = "tab"
    var route: String = "PO"
    var drugClass: String = ""
    var indication: String = ""
    var sig: String = ""
    var dosesPerDay: Double = 1
    var kind: String = "maint"          // maint | prn
    var slots: [String] = ["am"]
    var qty: Double = 0                  // quantity dispensed on `filled`
    var filled: String = ""             // yyyy-MM-dd
    var daysSupply: Double? = nil
    var refills: Int = 0
    var prescriber: String = ""
    var pharmacy: String = "VA CMOP (mail)"
    var rx: String = ""
    var schedule: String = ""            // controlled-substance schedule, "" if none
    var fulfil: String = "mail"
    var cold: Bool = false
    var status: String = "active"
    var notes: String = ""
    var history: [HistoryEntry] = []

    var isActive: Bool { status == "active" }
    var displayName: String { brand.isEmpty ? generic : "\(generic) (\(brand))" }
}

struct AppSettings: Codable {
    var lead: Double = 10        // mail-order lead time (days)
    var ship: Double = 6         // overdue threshold (days on hand)
    var renewLead: Double = 21   // renewal lead when 0 refills
    var ctrlExtra: Double = 4    // extra days for controlled substances
    var coldExtra: Double = 3    // extra days for cold-chain meds
}
