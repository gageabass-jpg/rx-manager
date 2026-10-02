import Foundation

/// A prescribable medication product returned from an RxNorm search,
/// parsed into the fields the add/edit form needs.
struct DrugHit: Identifiable, Hashable {
    let rxcui: String
    let fullName: String   // original RxNorm name, e.g. "lisinopril 10 MG Oral Tablet [Prinivil]"
    let tty: String        // SCD (generic) or SBD (branded)
    let generic: String
    let brand: String
    let strength: String
    let form: String

    var id: String { rxcui }
    var isBranded: Bool { tty == "SBD" }
}

/// Thin client for the NIH / National Library of Medicine RxNorm API.
/// Public domain, no API key required. https://rxnav.nlm.nih.gov/
enum RxNormService {
    private static let base = "https://rxnav.nlm.nih.gov/REST"

    struct ServiceError: Error {}

    // MARK: Search

    static func search(_ term: String) async throws -> [DrugHit] {
        let q = term.trimmingCharacters(in: .whitespaces)
        guard q.count >= 2 else { return [] }

        var comps = URLComponents(string: "\(base)/drugs.json")!
        comps.queryItems = [URLQueryItem(name: "name", value: q)]

        let (data, resp) = try await URLSession.shared.data(from: comps.url!)
        // Treat any non-200 (rate limit, transient 5xx) as a reachability error
        // so the UI offers a retry rather than a misleading "no matches".
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else { throw ServiceError() }

        let decoded = try JSONDecoder().decode(DrugsResponse.self, from: data)
        let groups = decoded.drugGroup.conceptGroup ?? []

        var hits: [DrugHit] = []
        var seen = Set<String>()
        // Generics (SCD) first, then branded (SBD) — this app leans generic.
        for wanted in ["SCD", "SBD"] {
            for group in groups where group.tty == wanted {
                for c in group.conceptProperties ?? [] {
                    guard !seen.contains(c.rxcui) else { continue }
                    seen.insert(c.rxcui)
                    let p = parse(name: c.name)
                    hits.append(DrugHit(rxcui: c.rxcui, fullName: c.name, tty: wanted,
                                        generic: p.generic, brand: p.brand,
                                        strength: p.strength, form: p.form))
                }
            }
        }
        return hits
    }

    // MARK: Drug class (best-effort therapeutic class via ATC)

    static func drugClass(rxcui: String) async throws -> String? {
        var comps = URLComponents(string: "\(base)/rxclass/class/byRxcui.json")!
        comps.queryItems = [
            URLQueryItem(name: "rxcui", value: rxcui),
            URLQueryItem(name: "relaSource", value: "ATC")
        ]
        let (data, resp) = try await URLSession.shared.data(from: comps.url!)
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else { return nil }

        let decoded = try JSONDecoder().decode(ClassResponse.self, from: data)
        let items = (decoded.rxclassDrugInfoList?.rxclassDrugInfo ?? [])
            .compactMap { $0.rxclassMinConceptItem }
        // Longest ATC classId == most specific therapeutic class.
        guard let best = items.max(by: { $0.classId.count < $1.classId.count }) else { return nil }
        let name = best.className.trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? nil : name
    }

    // MARK: Name parsing

    private static let formMap: [(String, String)] = [
        ("Extended Release Oral Capsule", "ER cap"),
        ("Extended Release Oral Tablet", "ER tab"),
        ("Delayed Release Oral Capsule", "DR cap"),
        ("Delayed Release Oral Tablet", "DR tab"),
        ("Disintegrating Oral Tablet", "ODT"),
        ("Chewable Tablet", "chew tab"),
        ("Oral Tablet", "tab"),
        ("Oral Capsule", "cap"),
        ("Oral Solution", "soln"),
        ("Oral Suspension", "susp"),
        ("Ophthalmic Solution", "eye soln"),
        ("Metered Dose Inhaler", "inhaler"),
        ("Dry Powder Inhaler", "inhaler"),
        ("Transdermal System", "patch"),
        ("Prefilled Syringe", "syringe"),
        ("Injectable Solution", "injection"),
        ("Rectal Suppository", "suppository"),
        ("Topical Cream", "cream"),
        ("Topical Ointment", "ointment"),
        ("Injection", "injection")
    ]

    private static let unitMap: [String: String] = [
        "MG": "mg", "MCG": "mcg", "ML": "mL", "MEQ": "mEq",
        "UNT": "unit", "IU": "IU", "G": "g", "MMOL": "mmol"
    ]

    /// Parse a full RxNorm name into (generic, brand, strength, form).
    static func parse(name: String) -> (generic: String, brand: String, strength: String, form: String) {
        var s = name
        var brand = ""

        // Brand lives in [brackets].
        if let r = s.range(of: #"\[[^\]]+\]"#, options: .regularExpression) {
            brand = String(s[r]).trimmingCharacters(in: CharacterSet(charactersIn: "[] "))
            s.removeSubrange(r)
        }

        // Strength tokens: number + dose unit, optionally a ratio (e.g. 100 UNT/ML).
        let unitAlt = unitMap.keys.joined(separator: "|")
        let pattern = "\\d[\\d.]*\\s*(?:\(unitAlt))(?:\\s*/\\s*[\\d.]*\\s*(?:\(unitAlt)))?"
        var strengths: [String] = []
        if let rx = try? NSRegularExpression(pattern: pattern) {
            let ns = s as NSString
            for m in rx.matches(in: s, range: NSRange(location: 0, length: ns.length)) {
                strengths.append(ns.substring(with: m.range))
            }
            s = rx.stringByReplacingMatches(in: s, range: NSRange(location: 0, length: ns.length), withTemplate: " ")
        }
        let strength = strengths.map(normalizeUnits).joined(separator: " / ")

        // Release duration (e.g. "24 HR") belongs to the form, not the name.
        s = s.replacingOccurrences(of: #"\d+\s*HR"#, with: " ", options: .regularExpression)

        // Dose form.
        var form = ""
        for (phrase, short) in formMap {
            if let r = s.range(of: phrase, options: .caseInsensitive) {
                form = short
                s.removeSubrange(r)
                break
            }
        }

        // Whatever remains is the ingredient(s).
        let generic = s
            .replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\s*/\s*"#, with: " / ", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: " /"))

        return (generic, brand, strength, form)
    }

    private static func normalizeUnits(_ token: String) -> String {
        var out = token.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
        for (upper, nice) in unitMap {
            out = out.replacingOccurrences(of: "\\b\(upper)\\b", with: nice, options: [.regularExpression, .caseInsensitive])
        }
        return out
    }
}

// MARK: - API response models

private struct DrugsResponse: Codable {
    let drugGroup: DrugGroup
}
private struct DrugGroup: Codable {
    let conceptGroup: [ConceptGroup]?
}
private struct ConceptGroup: Codable {
    let tty: String?
    let conceptProperties: [ConceptProperty]?
}
private struct ConceptProperty: Codable {
    let rxcui: String
    let name: String
}

private struct ClassResponse: Codable {
    let rxclassDrugInfoList: RxclassDrugInfoList?
}
private struct RxclassDrugInfoList: Codable {
    let rxclassDrugInfo: [RxclassDrugInfo]?
}
private struct RxclassDrugInfo: Codable {
    let rxclassMinConceptItem: RxclassMinConceptItem?
}
private struct RxclassMinConceptItem: Codable {
    let classId: String
    let className: String
}
