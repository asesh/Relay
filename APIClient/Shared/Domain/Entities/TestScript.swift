import Foundation

// MARK: - TestScript

public struct TestScript: Codable, Sendable {
    public var source: String
    public var isEnabled: Bool

    public init(source: String = "", isEnabled: Bool = true) {
        self.source = source
        self.isEnabled = isEnabled
    }
}

// MARK: - PreRequestScript

public struct PreRequestScript: Codable, Sendable {
    public var source: String
    public var isEnabled: Bool

    public init(source: String = "", isEnabled: Bool = true) {
        self.source = source
        self.isEnabled = isEnabled
    }
}

// MARK: - Script Console Entry

public struct ScriptConsoleEntry: Identifiable, Sendable {
    public var id: UUID
    public var level: LogLevel
    public var message: String
    public var timestamp: Date

    public enum LogLevel: Sendable {
        case log, warn, error
    }

    public init(id: UUID = UUID(), level: LogLevel = .log, message: String, timestamp: Date = Date()) {
        self.id = id; self.level = level; self.message = message; self.timestamp = timestamp
    }
}

// MARK: - Script Execution Result

public struct ScriptExecutionResult: Sendable {
    public var consoleOutput: [ScriptConsoleEntry]
    public var testResults: [TestResult]
    public var error: String?
    public var mutatedRequest: HTTPRequest?

    public init(
        consoleOutput: [ScriptConsoleEntry] = [],
        testResults: [TestResult] = [],
        error: String? = nil,
        mutatedRequest: HTTPRequest? = nil
    ) {
        self.consoleOutput = consoleOutput
        self.testResults = testResults
        self.error = error
        self.mutatedRequest = mutatedRequest
    }
}
