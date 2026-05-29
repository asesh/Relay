import Foundation
import SwiftData

@Model
public final class MockServerModel {
    public var id: UUID
    public var name: String
    public var port: Int
    public var isRunning: Bool
    public var description: String
    public var createdAt: Date
    public var workspace: WorkspaceModel?

    @Relationship(deleteRule: .cascade, inverse: \MockRouteModel.server)
    public var routes: [MockRouteModel]

    public init(
        id: UUID = UUID(),
        name: String = "Mock Server",
        port: Int = 3000,
        isRunning: Bool = false,
        description: String = "",
        workspace: WorkspaceModel? = nil
    ) {
        self.id = id; self.name = name; self.port = port
        self.isRunning = isRunning; self.description = description
        self.createdAt = Date(); self.workspace = workspace
        self.routes = []
    }
}

@Model
public final class MockRouteModel {
    public var id: UUID
    public var method: String
    public var path: String
    public var statusCode: Int
    public var responseBody: String
    public var responseHeadersData: Data?
    public var delayMs: Int
    public var isEnabled: Bool
    public var sortOrder: Int
    public var conditionalRulesData: Data?
    public var server: MockServerModel?

    public init(
        id: UUID = UUID(),
        method: String = "GET",
        path: String = "/",
        statusCode: Int = 200,
        responseBody: String = "{}",
        delayMs: Int = 0,
        isEnabled: Bool = true,
        sortOrder: Int = 0,
        server: MockServerModel? = nil
    ) {
        self.id = id; self.method = method; self.path = path
        self.statusCode = statusCode; self.responseBody = responseBody
        self.delayMs = delayMs; self.isEnabled = isEnabled
        self.sortOrder = sortOrder; self.server = server
    }

    public var responseHeaders: [String: String] {
        get {
            guard let data = responseHeadersData else { return [:] }
            return (try? JSONDecoder().decode([String: String].self, from: data)) ?? [:]
        }
        set { responseHeadersData = try? JSONEncoder().encode(newValue) }
    }

    public var conditionalRules: [MockConditionalRule] {
        get {
            guard let data = conditionalRulesData else { return [] }
            return (try? JSONDecoder().decode([MockConditionalRule].self, from: data)) ?? []
        }
        set { conditionalRulesData = try? JSONEncoder().encode(newValue) }
    }
}

// MARK: - Mock Conditional Rule

public struct MockConditionalRule: Identifiable, Codable, Sendable {
    public var id: UUID
    public var condition: MatchCondition
    public var key: String
    public var value: String
    public var responseStatusCode: Int
    public var responseBody: String

    public enum MatchCondition: String, Codable, Sendable, CaseIterable {
        case headerEquals = "Header Equals"
        case bodyContains = "Body Contains"
        case queryParamEquals = "Query Param Equals"
    }

    public init(
        id: UUID = UUID(),
        condition: MatchCondition = .headerEquals,
        key: String = "", value: String = "",
        responseStatusCode: Int = 200, responseBody: String = "{}"
    ) {
        self.id = id; self.condition = condition; self.key = key
        self.value = value; self.responseStatusCode = responseStatusCode
        self.responseBody = responseBody
    }
}
