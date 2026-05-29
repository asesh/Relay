import Foundation
import JavaScriptCore

// MARK: - Script Engine

/// Executes pre-request and test scripts in an isolated JSContext.
@MainActor
public final class ScriptEngine: ObservableObject {

    public init() {}

    /// Execute a script with access to the pm.* API.
    /// - Parameters:
    ///   - source: JavaScript source code
    ///   - request: Current HTTP request (may be mutated by pre-request scripts)
    ///   - response: HTTP response (available in test scripts)
    ///   - resolver: Variable resolver for reading/writing variables
    /// - Returns: ScriptExecutionResult containing console output, test results, and mutations
    public func execute(
        source: String,
        request: HTTPRequest,
        response: HTTPResponse? = nil,
        resolver: VariableResolver,
        variables: inout [String: String]  // mutable local variables
    ) async -> ScriptExecutionResult {
        guard !source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return ScriptExecutionResult()
        }

        return await withCheckedContinuation { continuation in
            let context = JSContext()!
            context.exceptionHandler = { _, exception in
                // Captured below via exception checking
                _ = exception
            }

            var consoleOutput: [ScriptConsoleEntry] = []
            var testResults: [TestResult] = []
            var mutatedRequest = request
            var localVars = variables

            // MARK: Console
            setupConsole(context: context, output: &consoleOutput)

            // MARK: pm object
            let pm = JSValue(newObjectIn: context)!
            setupEnvironment(pm: pm, context: context, resolver: resolver, localVars: &localVars)
            setupRequest(pm: pm, context: context, request: &mutatedRequest)
            if let response { setupResponse(pm: pm, context: context, response: response) }
            setupTest(pm: pm, context: context, testResults: &testResults)
            context.setObject(pm, forKeyedSubscript: "pm" as NSString)

            // MARK: Execute with timeout
            let workItem = DispatchWorkItem {
                context.evaluateScript(source)
                let exception = context.exception
                variables = localVars
                let error = exception.flatMap { $0.isUndefined ? nil : $0.toString() }
                continuation.resume(returning: ScriptExecutionResult(
                    consoleOutput: consoleOutput,
                    testResults: testResults,
                    error: error,
                    mutatedRequest: mutatedRequest
                ))
            }
            DispatchQueue.global(qos: .userInitiated).async(execute: workItem)
            DispatchQueue.global(qos: .userInitiated).asyncAfter(
                deadline: .now() + Constants.scriptTimeoutSeconds
            ) {
                if !workItem.isCancelled {
                    workItem.cancel()
                    continuation.resume(returning: ScriptExecutionResult(
                        consoleOutput: consoleOutput,
                        testResults: testResults,
                        error: "Script execution timed out after \(Int(Constants.scriptTimeoutSeconds))s"
                    ))
                }
            }
        }
    }

    // MARK: - Console Setup

    private func setupConsole(context: JSContext, output: inout [ScriptConsoleEntry]) {
        let console = JSValue(newObjectIn: context)!
        var capturedOutput = output

        let logBlock: @convention(block) (JSValue) -> Void = { val in
            capturedOutput.append(ScriptConsoleEntry(level: .log, message: val.toString()))
        }
        let warnBlock: @convention(block) (JSValue) -> Void = { val in
            capturedOutput.append(ScriptConsoleEntry(level: .warn, message: val.toString()))
        }
        let errorBlock: @convention(block) (JSValue) -> Void = { val in
            capturedOutput.append(ScriptConsoleEntry(level: .error, message: val.toString()))
        }
        console.setObject(logBlock, forKeyedSubscript: "log" as NSString)
        console.setObject(warnBlock, forKeyedSubscript: "warn" as NSString)
        console.setObject(errorBlock, forKeyedSubscript: "error" as NSString)
        context.setObject(console, forKeyedSubscript: "console" as NSString)
        output = capturedOutput
    }

    // MARK: - Environment Setup

    private func setupEnvironment(pm: JSValue, context: JSContext, resolver: VariableResolver, localVars: inout [String: String]) {
        var capturedLocals = localVars
        let envObj = JSValue(newObjectIn: context)!

        let getBlock: @convention(block) (String) -> String? = { key in
            resolver.resolve(key)
        }
        let setBlock: @convention(block) (String, String) -> Void = { key, value in
            capturedLocals[key] = value
        }
        let unsetBlock: @convention(block) (String) -> Void = { key in
            capturedLocals.removeValue(forKey: key)
        }
        envObj.setObject(getBlock, forKeyedSubscript: "get" as NSString)
        envObj.setObject(setBlock, forKeyedSubscript: "set" as NSString)
        envObj.setObject(unsetBlock, forKeyedSubscript: "unset" as NSString)
        pm.setObject(envObj, forKeyedSubscript: "environment" as NSString)

        // pm.globals and pm.collectionVariables share the same object for simplicity
        pm.setObject(envObj, forKeyedSubscript: "globals" as NSString)
        pm.setObject(envObj, forKeyedSubscript: "collectionVariables" as NSString)

        // pm.variables.get — searches all scopes
        let varsObj = JSValue(newObjectIn: context)!
        let varsGetBlock: @convention(block) (String) -> String? = { key in
            resolver.resolve(key) ?? capturedLocals[key]
        }
        varsObj.setObject(varsGetBlock, forKeyedSubscript: "get" as NSString)
        pm.setObject(varsObj, forKeyedSubscript: "variables" as NSString)
        localVars = capturedLocals
    }

    // MARK: - Request Setup

    private func setupRequest(pm: JSValue, context: JSContext, request: inout HTTPRequest) {
        let reqObj = JSValue(newObjectIn: context)!
        reqObj.setObject(request.url, forKeyedSubscript: "url" as NSString)
        reqObj.setObject(request.effectiveMethodName, forKeyedSubscript: "method" as NSString)

        // Headers as object
        let headersObj = JSValue(newObjectIn: context)!
        for h in request.headers where h.isEnabled {
            headersObj.setObject(h.value, forKeyedSubscript: h.key as NSString)
        }
        reqObj.setObject(headersObj, forKeyedSubscript: "headers" as NSString)

        // Body
        if request.body.type == .raw {
            reqObj.setObject(request.body.rawContent, forKeyedSubscript: "body" as NSString)
        }

        // Allow mutation of URL
        var capturedRequest = request
        let setUrlBlock: @convention(block) (String) -> Void = { newURL in
            capturedRequest.url = newURL
        }
        reqObj.setObject(setUrlBlock, forKeyedSubscript: "setUrl" as NSString)
        pm.setObject(reqObj, forKeyedSubscript: "request" as NSString)
        request = capturedRequest
    }

    // MARK: - Response Setup

    private func setupResponse(pm: JSValue, context: JSContext, response: HTTPResponse) {
        let respObj = JSValue(newObjectIn: context)!
        respObj.setObject(response.statusCode, forKeyedSubscript: "code" as NSString)
        respObj.setObject(response.durationMs, forKeyedSubscript: "responseTime" as NSString)
        respObj.setObject(response.bodyString ?? "", forKeyedSubscript: "text" as NSString)

        // json() method
        let jsonBlock: @convention(block) () -> JSValue = {
            if let str = response.bodyString,
               let data = str.data(using: .utf8),
               let obj = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) {
                return JSValue(object: obj, in: context)!
            }
            return JSValue(nullIn: context)
        }
        respObj.setObject(jsonBlock, forKeyedSubscript: "json" as NSString)

        let textBlock: @convention(block) () -> String = { response.bodyString ?? "" }
        respObj.setObject(textBlock, forKeyedSubscript: "text" as NSString)

        // headers object
        let headersObj = JSValue(newObjectIn: context)!
        for (k, v) in response.headers { headersObj.setObject(v, forKeyedSubscript: k as NSString) }
        let getHeaderBlock: @convention(block) (String) -> String? = { key in
            response.headers[key] ?? response.headers[key.lowercased()]
        }
        headersObj.setObject(getHeaderBlock, forKeyedSubscript: "get" as NSString)
        respObj.setObject(headersObj, forKeyedSubscript: "headers" as NSString)

        pm.setObject(respObj, forKeyedSubscript: "response" as NSString)
    }

    // MARK: - Test Setup (pm.test + pm.expect)

    private func setupTest(pm: JSValue, context: JSContext, testResults: inout [TestResult]) {
        var capturedResults = testResults

        // pm.test("name", fn)
        let testBlock: @convention(block) (String, JSValue) -> Void = { name, fn in
            var passed = false
            var errorMsg: String?
            if fn.isObject {
                let result = fn.call(withArguments: [])
                if let ex = context.exception {
                    errorMsg = ex.toString()
                    context.exception = nil
                } else {
                    passed = result?.toBool() ?? true
                }
            }
            capturedResults.append(TestResult(name: name, passed: passed, errorMessage: errorMsg))
        }
        pm.setObject(testBlock, forKeyedSubscript: "test" as NSString)

        // pm.expect(value) — returns a ChaiBridge proxy
        let expectBlock: @convention(block) (JSValue) -> JSValue = { actual in
            ChaiBridge.makeBridge(actual: actual, context: context, results: &capturedResults)
        }
        pm.setObject(expectBlock, forKeyedSubscript: "expect" as NSString)
        testResults = capturedResults
    }
}

// MARK: - Chai Bridge

private enum ChaiBridge {

    static func makeBridge(actual: JSValue, context: JSContext, results: inout [TestResult]) -> JSValue {
        let bridge = JSValue(newObjectIn: context)!

        // .to property (returns self for chaining)
        bridge.setObject(bridge, forKeyedSubscript: "to" as NSString)
        bridge.setObject(bridge, forKeyedSubscript: "be" as NSString)
        bridge.setObject(bridge, forKeyedSubscript: "have" as NSString)
        bridge.setObject(bridge, forKeyedSubscript: "that" as NSString)
        bridge.setObject(bridge, forKeyedSubscript: "is" as NSString)
        bridge.setObject(bridge, forKeyedSubscript: "and" as NSString)
        bridge.setObject(bridge, forKeyedSubscript: "not" as NSString)

        var capturedResults = results

        let equalBlock: @convention(block) (JSValue) -> JSValue = { expected in
            let passed: Bool
            if actual.isString { passed = actual.toString() == expected.toString() }
            else if actual.isNumber { passed = actual.toDouble() == expected.toDouble() }
            else if actual.isBoolean { passed = actual.toBool() == expected.toBool() }
            else { passed = false }
            capturedResults.append(TestResult(
                name: "Expected \(actual.toString() ?? "nil") to equal \(expected.toString() ?? "nil")",
                passed: passed,
                errorMessage: passed ? nil : "Expected \(expected.toString() ?? "nil") but got \(actual.toString() ?? "nil")"
            ))
            results = capturedResults
            return bridge
        }
        bridge.setObject(equalBlock, forKeyedSubscript: "equal" as NSString)

        let includeBlock: @convention(block) (String) -> JSValue = { substring in
            let str = actual.toString() ?? ""
            let passed = str.contains(substring)
            capturedResults.append(TestResult(
                name: "Expected response to include '\(substring)'",
                passed: passed,
                errorMessage: passed ? nil : "'\(str)' does not include '\(substring)'"
            ))
            results = capturedResults
            return bridge
        }
        bridge.setObject(includeBlock, forKeyedSubscript: "include" as NSString)

        let aboveBlock: @convention(block) (Double) -> JSValue = { threshold in
            let num = actual.toDouble()
            let passed = num > threshold
            capturedResults.append(TestResult(
                name: "Expected \(num) to be above \(threshold)",
                passed: passed,
                errorMessage: passed ? nil : "\(num) is not above \(threshold)"
            ))
            results = capturedResults
            return bridge
        }
        bridge.setObject(aboveBlock, forKeyedSubscript: "above" as NSString)

        let belowBlock: @convention(block) (Double) -> JSValue = { threshold in
            let num = actual.toDouble()
            let passed = num < threshold
            capturedResults.append(TestResult(
                name: "Expected \(num) to be below \(threshold)",
                passed: passed
            ))
            results = capturedResults
            return bridge
        }
        bridge.setObject(belowBlock, forKeyedSubscript: "below" as NSString)

        let statusBlock: @convention(block) (Int) -> JSValue = { code in
            let actualCode = Int(actual.toInt32())
            let passed = actualCode == code
            capturedResults.append(TestResult(
                name: "Status code is \(code)",
                passed: passed,
                errorMessage: passed ? nil : "Expected status \(code), got \(actualCode)"
            ))
            results = capturedResults
            return bridge
        }
        bridge.setObject(statusBlock, forKeyedSubscript: "status" as NSString)

        let matchBlock: @convention(block) (String) -> JSValue = { pattern in
            let str = actual.toString() ?? ""
            let passed = (try? NSRegularExpression(pattern: pattern))
                .map { $0.firstMatch(in: str, range: NSRange(str.startIndex..., in: str)) != nil } ?? false
            capturedResults.append(TestResult(
                name: "Expected to match /\(pattern)/",
                passed: passed,
                errorMessage: passed ? nil : "'\(str)' does not match /\(pattern)/"
            ))
            results = capturedResults
            return bridge
        }
        bridge.setObject(matchBlock, forKeyedSubscript: "match" as NSString)

        results = capturedResults
        return bridge
    }
}
