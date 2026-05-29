import Foundation

// MARK: - Environment

public struct APIEnvironment: Identifiable, Codable, Sendable {
    public var id: UUID
    public var name: String
    public var variables: [EnvironmentVariable]
    public var colorHex: String

    public init(
        id: UUID = UUID(),
        name: String = "New Environment",
        variables: [EnvironmentVariable] = [],
        colorHex: String = "#3B82F6"
    ) {
        self.id = id
        self.name = name
        self.variables = variables
        self.colorHex = colorHex
    }

    public func resolve(_ key: String) -> String? {
        variables.first { $0.key == key && $0.isEnabled }?.currentValue
    }

    public var asDict: [String: String] {
        Dictionary(uniqueKeysWithValues: variables
            .filter { $0.isEnabled && !$0.key.isEmpty }
            .map { ($0.key, $0.currentValue) })
    }
}

// MARK: - Environment Variable

public struct EnvironmentVariable: Identifiable, Codable, Sendable {
    public var id: UUID
    public var key: String
    public var initialValue: String
    public var currentValue: String
    public var isEnabled: Bool
    public var isSecret: Bool
    public var type: VariableType

    public enum VariableType: String, Codable, Sendable, CaseIterable {
        case `default` = "default"
        case secret = "secret"
        case any = "any"
    }

    public init(
        id: UUID = UUID(),
        key: String = "",
        initialValue: String = "",
        currentValue: String = "",
        isEnabled: Bool = true,
        isSecret: Bool = false,
        type: VariableType = .default
    ) {
        self.id = id; self.key = key; self.initialValue = initialValue
        self.currentValue = currentValue.isEmpty ? initialValue : currentValue
        self.isEnabled = isEnabled; self.isSecret = isSecret; self.type = type
    }
}

// MARK: - Variable Scope

public enum VariableScope: String, Codable, Sendable, CaseIterable {
    case local = "Local"
    case data = "Data"
    case environment = "Environment"
    case collection = "Collection"
    case global = "Global"

    public var priority: Int {
        switch self {
        case .local: return 0
        case .data: return 1
        case .environment: return 2
        case .collection: return 3
        case .global: return 4
        }
    }
}
