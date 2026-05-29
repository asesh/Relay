import Foundation

// MARK: - KeyValuePair

public struct KeyValuePair: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var key: String
    public var value: String
    public var description: String
    public var isEnabled: Bool
    public var type: KeyValueType

    public init(
        id: UUID = UUID(),
        key: String = "",
        value: String = "",
        description: String = "",
        isEnabled: Bool = true,
        type: KeyValueType = .text
    ) {
        self.id = id
        self.key = key
        self.value = value
        self.description = description
        self.isEnabled = isEnabled
        self.type = type
    }
}

// MARK: - Key Value Type

public enum KeyValueType: String, Codable, Sendable {
    case text
    case file
    case secret
}

// MARK: - File Attachment

public struct FileAttachment: Identifiable, Codable, Sendable {
    public var id: UUID
    public var fileName: String
    public var mimeType: String
    public var fileSize: Int
    public var bookmarkData: Data?

    public init(
        id: UUID = UUID(),
        fileName: String,
        mimeType: String = "application/octet-stream",
        fileSize: Int = 0,
        bookmarkData: Data? = nil
    ) {
        self.id = id
        self.fileName = fileName
        self.mimeType = mimeType
        self.fileSize = fileSize
        self.bookmarkData = bookmarkData
    }

    public var formattedSize: String {
        let bytes = Double(fileSize)
        if bytes < 1024 { return "\(fileSize) B" }
        if bytes < 1024 * 1024 { return String(format: "%.1f KB", bytes / 1024) }
        return String(format: "%.1f MB", bytes / (1024 * 1024))
    }
}
