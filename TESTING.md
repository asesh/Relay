# Relay Testing & CI Documentation

## Test Coverage

This project includes comprehensive unit tests for all major components:

### Test Files

1. **RelayTests.swift** - Integration tests for relationships and workflows
2. **RelayUnitTests.swift** - Detailed unit tests for models, network service, and theme
3. **RelayViewTests.swift** - UI component tests for all views

### What's Tested

#### Models (`Models.swift`)
- ✅ CollectionItem initialization and default values
- ✅ RequestItem initialization with different HTTP methods
- ✅ HeaderItem creation and properties
- ✅ Relationships between collections, requests, and headers
- ✅ HTTPMethod and BodyType enums

#### Network Service (`NetworkService.swift`)
- ✅ HTTPResponse body string conversion
- ✅ JSON pretty printing
- ✅ Size string formatting (bytes, KB, MB)
- ✅ Duration string formatting (ms, seconds)
- ✅ Status code color mapping (2xx, 3xx, 4xx, 5xx)
- ✅ Singleton pattern for NetworkService

#### Theme (`Theme.swift`)
- ✅ HTTP method colors (GET, POST, PUT, DELETE, PATCH, HEAD)
- ✅ Status colors (success, redirect, client error, server error)
- ✅ Relay color scheme constants
- ✅ MethodBadge component rendering

#### Views
- ✅ ContentView and WelcomeView
- ✅ RequestEditorView with different body types
- ✅ HeadersEditorView with enabled/disabled headers
- ✅ SidebarView with collections and requests
- ✅ CollectionRow and RequestRow components
- ✅ BodyEditorView for all body types

## Running Tests

### Via Xcode
1. Open `Relay.xcodeproj` in Xcode
2. Press `⌘ + U` to run all tests
3. Or use the Test Navigator (`⌘ + 6`) to run individual test suites

### Via Command Line

```bash
# Run all tests
xcodebuild test \
  -project "Relay.xcodeproj" \
  -scheme Relay \
  -destination 'platform=iOS Simulator,name=iPhone 16'

# Run with code coverage
xcodebuild test \
  -project "Relay.xcodeproj" \
  -scheme Relay \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -enableCodeCoverage YES

# Run specific test file
xcodebuild test \
  -project "Relay.xcodeproj" \
  -scheme Relay \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:RelayTests/RelayUnitTests
```

## Continuous Integration

### GitHub Actions

The project uses GitHub Actions for automated testing on every push and pull request.

#### Workflow: `.github/workflows/swift-ci.yml`

**Triggers:**
- Push to `main` or `develop` branches
- Pull requests to `main` or `develop` branches

**Jobs:**

1. **build-and-test**
   - Builds the project on macOS with latest Xcode
   - Runs unit tests with code coverage
   - Runs UI tests
   - Uploads test results as artifacts

2. **lint**
   - Runs SwiftLint for code quality checks
   - Reports linting issues in GitHub Actions

#### Viewing CI Results

1. Go to the "Actions" tab in your GitHub repository
2. Click on any workflow run to see details
3. Download test artifacts from the workflow run page

### SwiftLint Configuration

Code quality rules are defined in `.swiftlint.yml`:

```bash
# Run SwiftLint locally
brew install swiftlint
swiftlint lint

# Auto-fix issues
swiftlint --fix
```

## Code Coverage Goals

Current coverage targets:
- Models: 90%+
- Network Service: 85%+
- Theme: 95%+
- Views: 70%+ (UI tests are more appropriate for full coverage)

To view coverage in Xcode:
1. Run tests with `⌘ + U`
2. Open the Report Navigator (`⌘ + 9`)
3. Select the latest test report
4. Click the "Coverage" tab

## Adding New Tests

### Test Structure

Tests use Swift Testing framework (`import Testing`):

```swift
import Testing
@testable import Relay

struct MyFeatureTests {
    @Test func testSomething() async throws {
        let result = someFunction()
        #expect(result == expectedValue)
    }
}
```

### Best Practices

1. **Test one thing per test** - Each `@Test` should verify a single behavior
2. **Use descriptive names** - Test names should clearly describe what's being tested
3. **Arrange-Act-Assert** - Structure tests with clear setup, action, and verification
4. **Test edge cases** - Include tests for empty values, nil, extremes, etc.
5. **Keep tests fast** - Unit tests should run in milliseconds

### Example Test

```swift
@Test func testHTTPResponseSizeStringKilobytes() async throws {
    // Arrange
    let data = Data(count: 2048) // 2 KB
    
    // Act
    let response = HTTPResponse(
        statusCode: 200,
        responseHeaders: [:],
        body: data,
        duration: 0.1
    )
    
    // Assert
    #expect(response.sizeString == "2.0 KB")
}
```

## Troubleshooting

### Tests Failing on CI but Passing Locally

1. Check Xcode version differences
2. Verify simulator availability
3. Review CI logs for environment-specific issues

### Slow Tests

1. Identify slow tests in the test report
2. Consider mocking network calls
3. Use in-memory SwiftData containers for faster tests

### Code Coverage Dropping

1. Review the coverage report
2. Add tests for new code
3. Ensure all branches are tested

## Contributing

When adding new features:
1. Write tests first (TDD approach)
2. Ensure all tests pass locally
3. Check that CI passes before merging
4. Maintain or improve code coverage

## Resources

- [Swift Testing Documentation](https://developer.apple.com/documentation/testing)
- [XCTest Framework](https://developer.apple.com/documentation/xctest)
- [GitHub Actions for iOS](https://docs.github.com/en/actions/automating-builds-and-tests/building-and-testing-swift)
- [SwiftLint Rules](https://realm.github.io/SwiftLint/rule-directory.html)
