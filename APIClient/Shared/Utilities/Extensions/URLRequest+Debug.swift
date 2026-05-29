import Foundation

// MARK: - URLRequest + Debug

public extension URLRequest {

    var debugDescription: String {
        var lines: [String] = []
        let method = httpMethod ?? "GET"
        let urlString = url?.absoluteString ?? "(no URL)"
        lines.append("curl -X \(method) '\(urlString)' \\")
        allHTTPHeaderFields?.sorted { $0.key < $1.key }.forEach { key, value in
            lines.append("  -H '\(key): \(value)' \\")
        }
        if let body = httpBody, let bodyStr = String(data: body, encoding: .utf8) {
            let escaped = bodyStr.replacingOccurrences(of: "'", with: "'\\''")
            lines.append("  -d '\(escaped)'")
        } else if lines.last?.hasSuffix(" \\") == true {
            lines[lines.count - 1] = String(lines[lines.count - 1].dropLast(2))
        }
        return lines.joined(separator: "\n")
    }

    func asCurlCommand() -> String {
        debugDescription
    }
}

// MARK: - String + Variable Tokens

public extension String {

    /// Extract all {{variable}} token names
    var variableTokens: [String] {
        var results: [String] = []
        let pattern = Constants.variablePattern
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(startIndex..., in: self)
        regex.enumerateMatches(in: self, range: range) { match, _, _ in
            guard let match, let captureRange = Range(match.range(at: 1), in: self) else { return }
            results.append(String(self[captureRange]))
        }
        return results
    }

    /// Replace {{variable}} tokens with values from a dictionary
    func resolvingVariables(_ variables: [String: String]) -> String {
        var result = self
        for (key, value) in variables {
            result = result.replacingOccurrences(of: "{{\(key)}}", with: value)
        }
        return result
    }

    /// Check if string contains any unresolved {{variable}} tokens
    var hasUnresolvedVariables: Bool { !variableTokens.isEmpty }

    func trimmingWhitespaceAndNewlines() -> String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
