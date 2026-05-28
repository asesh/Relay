import SwiftUI

enum RelayColor {
    case statusSuccess, statusRedirect, statusClientError, statusServerError
}

extension Color {
    static let relayBg = Color(red: 0.137, green: 0.137, blue: 0.137)
    static let relaySidebar = Color(red: 0.102, green: 0.102, blue: 0.102)
    static let relayPanel = Color(red: 0.173, green: 0.173, blue: 0.173)
    static let relayInputBg = Color(red: 0.196, green: 0.196, blue: 0.196)
    static let relayBorder = Color(red: 0.259, green: 0.259, blue: 0.259)
    static let relayAccent = Color(red: 1.0, green: 0.424, blue: 0.216)
    static let relaySecondary = Color(red: 0.62, green: 0.62, blue: 0.62)

    static func methodColor(_ method: String) -> Color {
        switch method {
        case "GET":     return Color(red: 0.38, green: 0.75, blue: 1.0)
        case "POST":    return Color(red: 0.29, green: 0.80, blue: 0.56)
        case "PUT":     return Color(red: 0.988, green: 0.635, blue: 0.188)
        case "DELETE":  return Color(red: 0.976, green: 0.243, blue: 0.243)
        case "PATCH":   return Color(red: 0.314, green: 0.89, blue: 0.761)
        case "HEAD":    return Color(red: 0.75, green: 0.38, blue: 1.0)
        default:        return Color(red: 0.7, green: 0.7, blue: 0.7)
        }
    }

    static func statusColor(_ relayColor: RelayColor) -> Color {
        switch relayColor {
        case .statusSuccess:     return Color(red: 0.29, green: 0.80, blue: 0.56)
        case .statusRedirect:    return Color(red: 0.988, green: 0.635, blue: 0.188)
        case .statusClientError: return Color(red: 0.976, green: 0.243, blue: 0.243)
        case .statusServerError: return Color(red: 0.976, green: 0.243, blue: 0.243)
        }
    }
}

struct MethodBadge: View {
    let method: String
    var small: Bool = false

    var body: some View {
        Text(method)
            .font(small ? .system(size: 9, weight: .bold) : .system(size: 11, weight: .bold))
            .foregroundStyle(Color.methodColor(method))
            .padding(.horizontal, small ? 4 : 6)
            .padding(.vertical, small ? 2 : 3)
            .background(Color.methodColor(method).opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 3))
    }
}
