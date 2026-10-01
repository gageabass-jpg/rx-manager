import SwiftUI

extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xff) / 255,
                  green: Double((hex >> 8) & 0xff) / 255,
                  blue: Double(hex & 0xff) / 255,
                  opacity: alpha)
    }
}

/// "Calm" design direction — light, rounded, friendly consumer-health look.
enum RxTheme {
    static let bg     = Color(hex: 0xf2f5f2)   // soft sage-tinted page
    static let card   = Color.white
    static let ink    = Color(hex: 0x26312c)   // deep green-gray text
    static let muted  = Color(hex: 0x7d8a82)
    static let accent = Color(hex: 0x2f9e8f)   // sage teal
    static let line   = Color(hex: 0xe6ebe6)

    static let cardRadius: CGFloat = 18
    static let cardShadow = Color(hex: 0x26312c).opacity(0.08)

    /// Visual style for a supply-urgency rank (0 ok … 5 out).
    struct Status {
        var fg: Color
        var tint: Color
        var label: String?
    }

    static func status(rank: Int, renewal: Bool) -> Status {
        switch rank {
        case 5: return Status(fg: Color(hex: 0xb42318), tint: Color(hex: 0xfbeae8), label: "Out")
        case 4: return Status(fg: Color(hex: 0xb42318), tint: Color(hex: 0xfbeae8), label: renewal ? "Overdue · renew" : "Overdue")
        case 3: return Status(fg: Color(hex: 0x534ab7), tint: Color(hex: 0xececfb), label: "Renewal soon")
        case 2: return Status(fg: Color(hex: 0xb54708), tint: Color(hex: 0xfbeadd), label: "Order now")
        case 1: return Status(fg: Color(hex: 0x534ab7), tint: Color(hex: 0xececfb), label: "0 refills")
        default: return Status(fg: Color(hex: 0x1d9e75), tint: Color(hex: 0xe3f3ee), label: nil)
        }
    }

    /// Friendly dosing phrase from doses-per-day.
    static func frequency(_ dpd: Double) -> String {
        switch Int(dpd.rounded()) {
        case ..<1: return "as needed"
        case 1: return "once daily"
        case 2: return "twice daily"
        case 3: return "three times daily"
        case 4: return "four times daily"
        default: return "\(Int(dpd.rounded()))× daily"
        }
    }
}
