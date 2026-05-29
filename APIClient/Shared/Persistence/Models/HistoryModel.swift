import Foundation
import SwiftData

@Model
public final class HistoryModel {
    public var id: UUID
    public var method: String
    public var url: String
    public var statusCode: Int
    public var durationMs: Int
    public var responseSizeBytes: Int
    public var timestamp: Date

    // Serialized request snapshot
    public var requestData: Data?
    // Serialized response headers
    public var responseHeadersData: Data?
    // Short response body preview
    public var responseBodyPreview: String

    public var workspace: WorkspaceModel?

    public init(
        id: UUID = UUID(),
        method: String = "GET",
        url: String = "",
        statusCode: Int = 0,
        durationMs: Int = 0,
        responseSizeBytes: Int = 0,
        timestamp: Date = Date(),
        requestData: Data? = nil,
        responseHeadersData: Data? = nil,
        responseBodyPreview: String = "",
        workspace: WorkspaceModel? = nil
    ) {
        self.id = id; self.method = method; self.url = url
        self.statusCode = statusCode; self.durationMs = durationMs
        self.responseSizeBytes = responseSizeBytes; self.timestamp = timestamp
        self.requestData = requestData
        self.responseHeadersData = responseHeadersData
        self.responseBodyPreview = responseBodyPreview
        self.workspace = workspace
    }

    public var savedRequest: HTTPRequest? {
        guard let data = requestData else { return nil }
        return try? JSONDecoder().decode(HTTPRequest.self, from: data)
    }

    public var statusCategory: StatusCategory {
        switch statusCode {
        case 200..<300: return .success
        case 300..<400: return .redirection
        case 400..<500: return .clientError
        case 500..<600: return .serverError
        default: return .unknown
        }
    }
}

@Model
public final class TabSessionModel {
    public var id: UUID
    public var tabOrder: [String]   // JSON array of RequestModel IDs
    public var activeTabID: String?
    public var workspace: WorkspaceModel?

    public init(
        id: UUID = UUID(),
        tabOrder: [String] = [],
        activeTabID: String? = nil,
        workspace: WorkspaceModel? = nil
    ) {
        self.id = id; self.tabOrder = tabOrder
        self.activeTabID = activeTabID; self.workspace = workspace
    }
}
