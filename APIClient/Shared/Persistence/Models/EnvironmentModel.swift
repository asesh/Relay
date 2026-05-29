import Foundation
import SwiftData

@Model
public final class EnvironmentModel {
    public var id: UUID
    public var name: String
    public var colorHex: String
    public var isActive: Bool
    public var isGlobal: Bool
    public var sortOrder: Int
    public var createdAt: Date
    public var workspace: WorkspaceModel?

    @Relationship(deleteRule: .cascade, inverse: \VariableModel.environment)
    public var variables: [VariableModel]

    public init(
        id: UUID = UUID(),
        name: String = "New Environment",
        colorHex: String = "#10B981",
        isActive: Bool = false,
        isGlobal: Bool = false,
        sortOrder: Int = 0,
        workspace: WorkspaceModel? = nil
    ) {
        self.id = id; self.name = name; self.colorHex = colorHex
        self.isActive = isActive; self.isGlobal = isGlobal
        self.sortOrder = sortOrder; self.createdAt = Date()
        self.workspace = workspace; self.variables = []
    }

    public func toAPIEnvironment() -> APIEnvironment {
        let vars = variables.map { v in
            EnvironmentVariable(
                id: v.id, key: v.key,
                initialValue: v.initialValue,
                currentValue: v.currentValue,
                isEnabled: v.isEnabled,
                isSecret: v.isSecret,
                type: EnvironmentVariable.VariableType(rawValue: v.type) ?? .default
            )
        }
        return APIEnvironment(id: id, name: name, variables: vars, colorHex: colorHex)
    }
}

@Model
public final class VariableModel {
    public var id: UUID
    public var key: String
    public var initialValue: String
    public var currentValue: String
    public var isEnabled: Bool
    public var isSecret: Bool
    public var type: String         // "default" | "secret" | "any"
    public var sortOrder: Int
    public var environment: EnvironmentModel?

    public init(
        id: UUID = UUID(),
        key: String = "", initialValue: String = "",
        currentValue: String = "", isEnabled: Bool = true,
        isSecret: Bool = false, type: String = "default",
        sortOrder: Int = 0, environment: EnvironmentModel? = nil
    ) {
        self.id = id; self.key = key; self.initialValue = initialValue
        self.currentValue = currentValue.isEmpty ? initialValue : currentValue
        self.isEnabled = isEnabled; self.isSecret = isSecret
        self.type = type; self.sortOrder = sortOrder
        self.environment = environment
    }
}
