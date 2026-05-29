import Foundation

// MARK: - Variable Resolver

/// Resolves {{variable}} tokens through the scope chain:
/// local → data → environment → collection → global
public final class VariableResolver: Sendable {

    private let globalVars: [String: String]
    private let collectionVars: [String: String]
    private let environmentVars: [String: String]
    private let dataVars: [String: String]
    private let localVars: [String: String]

    public init(
        globalVars: [String: String] = [:],
        collectionVars: [String: String] = [:],
        environmentVars: [String: String] = [:],
        dataVars: [String: String] = [:],
        localVars: [String: String] = [:]
    ) {
        self.globalVars = globalVars
        self.collectionVars = collectionVars
        self.environmentVars = environmentVars
        self.dataVars = dataVars
        self.localVars = localVars
    }

    // MARK: - Resolution

    /// Returns resolved value for a key, searching through scope chain.
    public func resolve(_ key: String) -> String? {
        // local wins first
        if let v = localVars[key] { return v }
        if let v = dataVars[key] { return v }
        if let v = environmentVars[key] { return v }
        if let v = collectionVars[key] { return v }
        if let v = globalVars[key] { return v }
        return nil
    }

    /// Substitute all {{var}} tokens in a string with resolved values.
    public func resolve(string: String) -> String {
        guard string.contains("{{") else { return string }
        var result = string
        let pattern = Constants.variablePattern
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return string }

        let nsString = result as NSString
        let matches = regex.matches(in: result, range: NSRange(location: 0, length: nsString.length))

        // Process in reverse order to preserve offsets
        for match in matches.reversed() {
            guard let captureRange = Range(match.range(at: 1), in: result) else { continue }
            let key = String(result[captureRange])
            if let value = resolve(key) {
                guard let fullRange = Range(match.range, in: result) else { continue }
                result.replaceSubrange(fullRange, with: value)
            }
        }
        return result
    }

    /// Resolve all {{var}} tokens in an HTTPRequest's URL, headers, params, and body.
    public func resolve(request: HTTPRequest) -> HTTPRequest {
        var resolved = request
        resolved.url = resolve(string: request.url)

        resolved.queryParams = request.queryParams.map { param in
            var p = param
            p.key = resolve(string: param.key)
            p.value = resolve(string: param.value)
            return p
        }

        resolved.headers = request.headers.map { header in
            var h = header
            h.key = resolve(string: header.key)
            h.value = resolve(string: header.value)
            return h
        }

        // Resolve body
        switch request.body.type {
        case .raw:
            resolved.body.rawContent = resolve(string: request.body.rawContent)
        case .urlEncoded:
            resolved.body.urlEncodedItems = request.body.urlEncodedItems.map { item in
                var i = item
                i.key = resolve(string: item.key)
                i.value = resolve(string: item.value)
                return i
            }
        case .formData:
            resolved.body.formDataItems = request.body.formDataItems.map { item in
                var i = item
                i.key = resolve(string: item.key)
                i.textValue = resolve(string: item.textValue)
                return i
            }
        case .graphQL:
            resolved.body.graphQL.query = resolve(string: request.body.graphQL.query)
            resolved.body.graphQL.variables = resolve(string: request.body.graphQL.variables)
        default: break
        }

        return resolved
    }

    // MARK: - Token Inspection

    /// Returns all variable tokens found in a string.
    public func tokens(in string: String) -> [VariableToken] {
        guard string.contains("{{") else { return [] }
        var tokens: [VariableToken] = []
        guard let regex = try? NSRegularExpression(pattern: Constants.variablePattern) else { return [] }
        let nsString = string as NSString
        let matches = regex.matches(in: string, range: NSRange(location: 0, length: nsString.length))
        for match in matches {
            guard let captureRange = Range(match.range(at: 1), in: string) else { continue }
            let key = String(string[captureRange])
            let value = resolve(key)
            tokens.append(VariableToken(
                name: key,
                resolvedValue: value,
                isResolved: value != nil,
                range: match.range
            ))
        }
        return tokens
    }

    // MARK: - Builder

    public func withLocal(_ vars: [String: String]) -> VariableResolver {
        VariableResolver(
            globalVars: globalVars, collectionVars: collectionVars,
            environmentVars: environmentVars, dataVars: dataVars,
            localVars: localVars.merging(vars) { _, new in new }
        )
    }

    public func withEnvironment(_ vars: [String: String]) -> VariableResolver {
        VariableResolver(
            globalVars: globalVars, collectionVars: collectionVars,
            environmentVars: vars, dataVars: dataVars, localVars: localVars
        )
    }

    public func withCollection(_ vars: [String: String]) -> VariableResolver {
        VariableResolver(
            globalVars: globalVars, collectionVars: vars,
            environmentVars: environmentVars, dataVars: dataVars, localVars: localVars
        )
    }
}

// MARK: - Variable Token

public struct VariableToken: Sendable {
    public var name: String
    public var resolvedValue: String?
    public var isResolved: Bool
    public var range: NSRange
}
