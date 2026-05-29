import Foundation

// MARK: - Data + Pretty

public extension Data {

    var prettyPrintedJSON: String? {
        guard let obj = try? JSONSerialization.jsonObject(with: self, options: []),
              let pretty = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]) else {
            return nil
        }
        return String(data: pretty, encoding: .utf8)
    }

    var jsonObject: Any? {
        try? JSONSerialization.jsonObject(with: self, options: [.fragmentsAllowed])
    }

    var utf8String: String? {
        String(data: self, encoding: .utf8)
    }

    var hexString: String {
        map { String(format: "%02X", $0) }.joined(separator: " ")
    }

    func hexDump(bytesPerRow: Int = 16) -> String {
        var result = ""
        var offset = 0
        while offset < count {
            let rowEnd = Swift.min(offset + bytesPerRow, count)
            let rowBytes = self[offset..<rowEnd]

            let addressStr = String(format: "%08X", offset)
            let hexStr = rowBytes.map { String(format: "%02X", $0) }.joined(separator: " ")
                .padding(toLength: bytesPerRow * 3 - 1, withPad: " ", startingAt: 0)
            let asciiStr = rowBytes.map { byte -> Character in
                let scalar = Unicode.Scalar(byte)
                let char = Character(scalar)
                return char.isASCII && !char.isNewline && byte >= 32 ? char : "."
            }
            result += "\(addressStr)  \(hexStr)  \(String(asciiStr))\n"
            offset += bytesPerRow
        }
        return result
    }

    var formattedSize: String {
        let bytes = Double(count)
        if bytes < 1024 { return "\(count) B" }
        if bytes < 1024 * 1024 { return String(format: "%.1f KB", bytes / 1024) }
        return String(format: "%.1f MB", bytes / (1024 * 1024))
    }
}
