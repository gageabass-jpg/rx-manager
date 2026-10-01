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

/// Rx Manager palette, carried over from the web app.
enum RxColor {
    static let ink = Color(hex: 0x16232e)
    static let accent = Color(hex: 0x0e7490)
    static let paper = Color(hex: 0xeef1f3)
    static let card = Color.white
    static let muted = Color(hex: 0x5c6b75)
    static let line = Color(hex: 0xc3cbd1)

    static let red = Color(hex: 0xb42318)
    static let amber = Color(hex: 0xb54708)
    static let indigo = Color(hex: 0x3538cd)
    static let ok = Color(hex: 0x17242e)

    /// Color for a supply-urgency rank (matches calc() tiers).
    static func rank(_ r: Int) -> Color {
        switch r {
        case 5, 4: return red
        case 3, 1: return indigo
        case 2:    return amber
        default:   return ok
        }
    }
}
