import Foundation
import SwiftData

@Model
public final class RequestModel {
    public var id: UUID
    public var name: String
    public var url: String
    public var method: String
    public var requestDescription: String
    public var sortOrder: Int
    public var createdAt: Date
    public var updatedAt: Date
    public var isFavorite: Bool

    // Body
    public var bodyType: String
    public var rawBodyType: String
    public var rawBodyContent: String
    public var formDataItemsData: Data?
    public var urlEncodedItemsData: Data?
    public var binaryFileData: Data?
    public var graphQLPayloadData: Data?

    // Auth (stored as JSON)
    public var authConfigData: Data?

    // Scripts
    public var preRequestScript: String
    public var testScript: String

    // Settings
    public var settingsData: Data?

    // Request type: http, websocket, graphql
    public var requestType: String

    public var collection: CollectionModel?
    public var folder: FolderModel?

    @Relationship(deleteRule: .cascade, inverse: \HeaderModel.request)
    public var headers: [HeaderModel]

    @Relationship(deleteRule: .cascade, inverse: \QueryParamModel.request)
    public var queryParams: [QueryParamModel]

    public init(
        id: UUID = UUID(),
        name: String = "New Request",
        url: String = "",
        method: String = "GET",
        requestDescription: String = "",
        sortOrder: Int = 0,
        collection: CollectionModel? = nil,
        folder: FolderModel? = nil,
        requestType: String = "http"
    ) {
        self.id = id; self.name = name; self.url = url; self.method = method
        self.requestDescription = requestDescription; self.sortOrder = sortOrder
        self.createdAt = Date(); self.updatedAt = Date()
        self.isFavorite = false
        self.bodyType = "none"; self.rawBodyType = "JSON"; self.rawBodyContent = ""
        self.preRequestScript = ""; self.testScript = ""
        self.requestType = requestType
        self.collection = collection; self.folder = folder
        self.headers = []; self.queryParams = []
    }

    // MARK: - Convenience computed properties

    public var authConfig: AuthConfig {
        get {
            guard let data = authConfigData else { return AuthConfig() }
            return (try? JSONDecoder().decode(AuthConfig.self, from: data)) ?? AuthConfig()
        }
        set { authConfigData = try? JSONEncoder().encode(newValue) }
    }

    public var settings: RequestSettings {
        get {
            guard let data = settingsData else { return RequestSettings() }
            return (try? JSONDecoder().decode(RequestSettings.self, from: data)) ?? RequestSettings()
        }
        set { settingsData = try? JSONEncoder().encode(newValue) }
    }

    public var formDataItems: [FormDataItem] {
        get {
            guard let data = formDataItemsData else { return [] }
            return (try? JSONDecoder().decode([FormDataItem].self, from: data)) ?? []
        }
        set { formDataItemsData = try? JSONEncoder().encode(newValue) }
    }

    public var urlEncodedItems: [KeyValuePair] {
        get {
            guard let data = urlEncodedItemsData else { return [] }
            return (try? JSONDecoder().decode([KeyValuePair].self, from: data)) ?? []
        }
        set { urlEncodedItemsData = try? JSONEncoder().encode(newValue) }
    }

    public var graphQLPayload: GraphQLPayload {
        get {
            guard let data = graphQLPayloadData else { return GraphQLPayload() }
            return (try? JSONDecoder().decode(GraphQLPayload.self, from: data)) ?? GraphQLPayload()
        }
        set { graphQLPayloadData = try? JSONEncoder().encode(newValue) }
    }

    /// Convert to domain HTTPRequest
    public func toHTTPRequest() -> HTTPRequest {
        let headerPairs = headers.map { h in
            KeyValuePair(id: h.id, key: h.key, value: h.value,
                         description: h.headerDescription, isEnabled: h.isEnabled)
        }
        let paramPairs = queryParams.map { p in
            KeyValuePair(id: p.id, key: p.key, value: p.value,
                         description: p.paramDescription, isEnabled: p.isEnabled)
        }
        let body = BodyPayload(
            type: BodyType(rawValue: bodyType) ?? .none,
            rawType: RawBodyType(rawValue: rawBodyType) ?? .json,
            rawContent: rawBodyContent,
            formDataItems: formDataItems,
            urlEncodedItems: urlEncodedItems,
            graphQL: graphQLPayload
        )
        return HTTPRequest(
            id: id, name: name,
            method: HTTPMethod.from(method),
            url: url, queryParams: paramPairs,
            headers: headerPairs, auth: authConfig,
            body: body, preRequestScript: preRequestScript,
            testScript: testScript, settings: settings,
            description: requestDescription
        )
    }

    /// Update from domain HTTPRequest
    public func update(from request: HTTPRequest) {
        name = request.name
        url = request.url
        method = request.effectiveMethodName
        requestDescription = request.description
        authConfig = request.auth
        preRequestScript = request.preRequestScript
        testScript = request.testScript
        settings = request.settings
        bodyType = request.body.type.rawValue
        rawBodyType = request.body.rawType.rawValue
        rawBodyContent = request.body.rawContent
        formDataItems = request.body.formDataItems
        urlEncodedItems = request.body.urlEncodedItems
        graphQLPayload = request.body.graphQL
        updatedAt = Date()
    }
}

@Model
public final class HeaderModel {
    public var id: UUID
    public var key: String
    public var value: String
    public var headerDescription: String
    public var isEnabled: Bool
    public var sortOrder: Int
    public var request: RequestModel?

    public init(
        id: UUID = UUID(),
        key: String = "", value: String = "",
        headerDescription: String = "",
        isEnabled: Bool = true, sortOrder: Int = 0,
        request: RequestModel? = nil
    ) {
        self.id = id; self.key = key; self.value = value
        self.headerDescription = headerDescription
        self.isEnabled = isEnabled; self.sortOrder = sortOrder
        self.request = request
    }
}

@Model
public final class QueryParamModel {
    public var id: UUID
    public var key: String
    public var value: String
    public var paramDescription: String
    public var isEnabled: Bool
    public var sortOrder: Int
    public var request: RequestModel?

    public init(
        id: UUID = UUID(),
        key: String = "", value: String = "",
        paramDescription: String = "",
        isEnabled: Bool = true, sortOrder: Int = 0,
        request: RequestModel? = nil
    ) {
        self.id = id; self.key = key; self.value = value
        self.paramDescription = paramDescription
        self.isEnabled = isEnabled; self.sortOrder = sortOrder
        self.request = request
    }
}
