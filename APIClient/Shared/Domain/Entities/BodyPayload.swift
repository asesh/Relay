import Foundation

// MARK: - BodyPayload

public struct BodyPayload: Codable, Sendable {
    public var type: BodyType
    public var rawType: RawBodyType
    public var rawContent: String
    public var formDataItems: [FormDataItem]
    public var urlEncodedItems: [KeyValuePair]
    public var binaryFile: FileAttachment?
    public var graphQL: GraphQLPayload

    public init(
        type: BodyType = .none,
        rawType: RawBodyType = .json,
        rawContent: String = "",
        formDataItems: [FormDataItem] = [],
        urlEncodedItems: [KeyValuePair] = [],
        binaryFile: FileAttachment? = nil,
        graphQL: GraphQLPayload = GraphQLPayload()
    ) {
        self.type = type
        self.rawType = rawType
        self.rawContent = rawContent
        self.formDataItems = formDataItems
        self.urlEncodedItems = urlEncodedItems
        self.binaryFile = binaryFile
        self.graphQL = graphQL
    }

    public var isEmpty: Bool {
        switch type {
        case .none: return true
        case .raw: return rawContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .formData: return formDataItems.filter(\.isEnabled).isEmpty
        case .urlEncoded: return urlEncodedItems.filter(\.isEnabled).isEmpty
        case .binary: return binaryFile == nil
        case .graphQL: return graphQL.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    public var effectiveContentType: String? {
        switch type {
        case .none: return nil
        case .raw: return rawType.contentType
        case .formData: return "multipart/form-data"
        case .urlEncoded: return "application/x-www-form-urlencoded"
        case .binary: return binaryFile?.mimeType ?? "application/octet-stream"
        case .graphQL: return "application/json"
        }
    }
}

// MARK: - Form Data Item

public struct FormDataItem: Identifiable, Codable, Sendable {
    public var id: UUID
    public var key: String
    public var textValue: String
    public var fileAttachment: FileAttachment?
    public var type: KeyValueType
    public var isEnabled: Bool
    public var description: String

    public init(
        id: UUID = UUID(),
        key: String = "",
        textValue: String = "",
        fileAttachment: FileAttachment? = nil,
        type: KeyValueType = .text,
        isEnabled: Bool = true,
        description: String = ""
    ) {
        self.id = id
        self.key = key
        self.textValue = textValue
        self.fileAttachment = fileAttachment
        self.type = type
        self.isEnabled = isEnabled
        self.description = description
    }
}

// MARK: - GraphQL Payload

public struct GraphQLPayload: Codable, Sendable {
    public var query: String
    public var variables: String   // JSON string
    public var operationName: String
    public var cachedSchema: GraphQLSchema?

    public init(
        query: String = "",
        variables: String = "{}",
        operationName: String = "",
        cachedSchema: GraphQLSchema? = nil
    ) {
        self.query = query
        self.variables = variables
        self.operationName = operationName
        self.cachedSchema = cachedSchema
    }

    public func toJSONBody() -> Data? {
        var dict: [String: Any] = ["query": query]
        if !operationName.isEmpty { dict["operationName"] = operationName }
        if let varData = variables.data(using: .utf8),
           let varObj = try? JSONSerialization.jsonObject(with: varData) {
            dict["variables"] = varObj
        }
        return try? JSONSerialization.data(withJSONObject: dict)
    }
}

// MARK: - GraphQL Schema (cached introspection result)

public struct GraphQLSchema: Codable, Sendable {
    public var url: String
    public var fetchedAt: Date
    public var types: [GraphQLType]

    public init(url: String, fetchedAt: Date = Date(), types: [GraphQLType] = []) {
        self.url = url
        self.fetchedAt = fetchedAt
        self.types = types
    }
}

public struct GraphQLType: Identifiable, Codable, Sendable {
    public var id: UUID
    public var name: String
    public var kind: String
    public var description: String?
    public var fields: [GraphQLField]

    public init(
        id: UUID = UUID(), name: String, kind: String = "OBJECT",
        description: String? = nil, fields: [GraphQLField] = []
    ) {
        self.id = id; self.name = name; self.kind = kind
        self.description = description; self.fields = fields
    }
}

public struct GraphQLField: Identifiable, Codable, Sendable {
    public var id: UUID
    public var name: String
    public var typeName: String
    public var description: String?
    public var args: [GraphQLArg]
    public var isDeprecated: Bool

    public init(
        id: UUID = UUID(), name: String, typeName: String = "",
        description: String? = nil, args: [GraphQLArg] = [],
        isDeprecated: Bool = false
    ) {
        self.id = id; self.name = name; self.typeName = typeName
        self.description = description; self.args = args; self.isDeprecated = isDeprecated
    }
}

public struct GraphQLArg: Identifiable, Codable, Sendable {
    public var id: UUID
    public var name: String
    public var typeName: String
    public var description: String?
    public var defaultValue: String?

    public init(
        id: UUID = UUID(), name: String, typeName: String = "",
        description: String? = nil, defaultValue: String? = nil
    ) {
        self.id = id; self.name = name; self.typeName = typeName
        self.description = description; self.defaultValue = defaultValue
    }
}
