import Foundation

// MARK: - Collection Runner

@MainActor
public final class CollectionRunner: ObservableObject {

    @Published public var isRunning = false
    @Published public var results: [RunResult] = []
    @Published public var progress: Double = 0
    @Published public var currentRequestName = ""

    private var isCancelled = false
    private let executor: RequestExecutor
    private let scriptEngine: ScriptEngine

    public init(executor: RequestExecutor = .shared, scriptEngine: ScriptEngine = ScriptEngine()) {
        self.executor = executor
        self.scriptEngine = scriptEngine
    }

    // MARK: - Run

    public func run(
        requests: [HTTPRequest],
        resolver: VariableResolver,
        options: RunnerOptions
    ) async {
        isRunning = true
        isCancelled = false
        results = []
        progress = 0

        let total = Double(requests.count * options.iterations)
        var completed: Double = 0
        var localVars: [String: String] = [:]

        for iteration in 0..<options.iterations {
            if isCancelled { break }

            // Load data variables from iteration
            let dataVars = options.dataRows.indices.contains(iteration)
                ? options.dataRows[iteration] : [:]
            let iterResolver = resolver.withLocal(dataVars.merging(localVars) { _, new in new })

            for request in requests {
                if isCancelled { break }

                currentRequestName = request.name
                if options.delayMs > 0 {
                    try? await Task.sleep(nanoseconds: UInt64(options.delayMs) * 1_000_000)
                }

                let startTime = Date()
                var result = RunResult(requestName: request.name, iteration: iteration + 1)

                do {
                    let response = try await executor.execute(
                        request: request, resolver: iterResolver,
                        scriptEngine: scriptEngine
                    )
                    result.statusCode = response.statusCode
                    result.durationMs = response.durationMs
                    result.size = response.bodySize
                    result.testResults = response.testResults
                    result.passed = response.testResults.allSatisfy(\.passed)
                } catch {
                    result.error = error.localizedDescription
                    result.passed = false
                }

                result.totalTimeMs = Int(Date().timeIntervalSince(startTime) * 1000)
                results.append(result)
                completed += 1
                progress = completed / total
            }
        }

        isRunning = false
        currentRequestName = ""
    }

    public func cancel() {
        isCancelled = true
    }

    // MARK: - Export

    public func exportAsJSON() -> Data? {
        try? JSONEncoder().encode(results)
    }

    public func exportAsJUnit() -> String {
        let total = results.count
        let failed = results.filter { !$0.passed }.count
        var xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <testsuites tests="\(total)" failures="\(failed)">
          <testsuite name="Collection Run" tests="\(total)" failures="\(failed)">\n
        """
        for result in results {
            xml += "    <testcase name=\"\(result.requestName) (iteration \(result.iteration))\" time=\"\(Double(result.durationMs) / 1000.0)\">\n"
            if !result.passed {
                xml += "      <failure message=\"\(result.error ?? "Test failed")\"/>\n"
            }
            xml += "    </testcase>\n"
        }
        xml += "  </testsuite>\n</testsuites>"
        return xml
    }
}

// MARK: - Runner Options

public struct RunnerOptions: Sendable {
    public var iterations: Int
    public var delayMs: Int
    public var dataRows: [[String: String]]
    public var environmentID: UUID?
    public var stopOnError: Bool

    public init(
        iterations: Int = 1,
        delayMs: Int = 0,
        dataRows: [[String: String]] = [],
        environmentID: UUID? = nil,
        stopOnError: Bool = false
    ) {
        self.iterations = iterations
        self.delayMs = delayMs
        self.dataRows = dataRows
        self.environmentID = environmentID
        self.stopOnError = stopOnError
    }
}

// MARK: - Run Result

public struct RunResult: Identifiable, Codable, Sendable {
    public var id: UUID = UUID()
    public var requestName: String
    public var iteration: Int
    public var statusCode: Int = 0
    public var durationMs: Int = 0
    public var size: Int = 0
    public var totalTimeMs: Int = 0
    public var testResults: [TestResult] = []
    public var passed: Bool = true
    public var error: String?

    public var passedCount: Int { testResults.filter(\.passed).count }
    public var failedCount: Int { testResults.filter { !$0.passed }.count }
}
