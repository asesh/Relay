import SwiftUI

// MARK: - Color + Scheme

public extension Color {

    // MARK: - HTTP Method Colors

    static func methodColor(_ method: String) -> Color {
        switch method.uppercased() {
        case "GET":     return Color(hex: "#10B981")  // green
        case "POST":    return Color(hex: "#3B82F6")  // blue
        case "PUT":     return Color(hex: "#F59E0B")  // amber
        case "PATCH":   return Color(hex: "#8B5CF6")  // violet
        case "DELETE":  return Color(hex: "#EF4444")  // red
        case "HEAD":    return Color(hex: "#06B6D4")  // cyan
        case "OPTIONS": return Color(hex: "#EC4899")  // pink
        default:        return Color(hex: "#6B7280")  // gray
        }
    }

    // MARK: - Status Code Colors

    static func statusColor(_ code: Int) -> Color {
        switch code {
        case 100..<200: return Color(hex: "#6B7280")  // gray
        case 200..<300: return Color(hex: "#10B981")  // green
        case 300..<400: return Color(hex: "#3B82F6")  // blue
        case 400..<500: return Color(hex: "#F59E0B")  // amber
        case 500..<600: return Color(hex: "#EF4444")  // red
        default:        return Color(hex: "#6B7280")
        }
    }

    // MARK: - Hex Init

    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch cleaned.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }

    var hexString: String {
        guard let components = cgColor?.components, components.count >= 3 else { return "#000000" }
        let r = Int(components[0] * 255)
        let g = Int(components[1] * 255)
        let b = Int(components[2] * 255)
        return String(format: "#%02X%02X%02X", r, g, b)
    }

    // MARK: - App Semantic Colors

    static var appBackground: Color { Color(.systemBackground) }
    static var appSecondaryBackground: Color { Color(.secondarySystemBackground) }
    static var appGroupedBackground: Color { Color(.systemGroupedBackground) }
    static var appSeparator: Color { Color(.separator) }
    static var appLabel: Color { Color(.label) }
    static var appSecondaryLabel: Color { Color(.secondaryLabel) }
    static var appTertiaryLabel: Color { Color(.tertiaryLabel) }
    static var codeBG: Color { Color(.systemBackground).opacity(0.5) }
}

// MARK: - View + Conditional Modifier

public extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition { transform(self) } else { self }
    }

    @ViewBuilder
    func ifLet<T, Content: View>(_ optional: T?, transform: (Self, T) -> Content) -> some View {
        if let value = optional { transform(self, value) } else { self }
    }
}
