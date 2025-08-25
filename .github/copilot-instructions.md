# SwiftBeanCountParser

SwiftBeanCountParser is a Swift Package Manager library that parses BeanCount (plain text accounting) format files into structured Swift objects using SwiftBeanCountModel. This library is part of the larger SwiftBeanCount ecosystem for double-entry bookkeeping in Swift.

Always reference these instructions first and fallback to search or bash commands only when you encounter unexpected information that does not match the info here.

## Working Effectively

- **Install Swift (if needed)**: Swift 6.1.2+ is required. The setup-swift GitHub Action installs it automatically in CI.
- **Install SwiftLint**: Check instructions in .github/ci.yml under the "SwiftLint" action, "Install SwiftLint" step
- **Build the library**: `swift build` -- takes 7 seconds clean build, <1 second for incremental builds. NEVER CANCEL. Set timeout to 3 minutes.
- **Run tests with coverage**: `swift test --enable-code-coverage` -- takes 15 seconds. NEVER CANCEL. Set timeout to 3 minutes. Must pass for CI to succeed and coverage must be > 97%.
- **Run linting**: `./swiftlint/swiftlint --strict` -- takes <1 second. Must pass for CI to succeed.

## Validation

- **ALWAYS run through complete parsing scenario after making changes**: Create a test BeanCount file and verify it parses correctly using the test suite.
- **ALWAYS run `./swiftlint/swiftlint --strict` before committing** or the CI (.github/workflows/ci.yml) will fail.
- **EACH COMMIT MUST BE ACCOMPANIED WITH PROPER TESTS**: Every code change should include appropriate test coverage to validate the functionality. The library has a requirement to keep line coverage above 97%, this is enforced via CI job which will fail otherwise.
- **CRITICAL validation**: After changes, run `swift test` and ensure all tests pass. Any test failure indicates broken functionality. The library has comprehensive test coverage with performance tests - these should continue to pass after changes.

## Common Tasks

### Build Times and Never Cancel Rules
- **NEVER CANCEL builds or tests** - All commands complete quickly but set reasonable timeouts
- `swift build`: 7 seconds clean build, <1 second incremental - Set timeout to 3 minutes
- `swift test`: 12 seconds - Set timeout to 3 minutes
- `swift test --enable-code-coverage`: 15 seconds - Set timeout to 3 minutes
- `./swiftlint/swiftlint --strict`: <1 second - Set timeout to 1 minute

### Key File Locations
- **Main parser entry point**: `Sources/SwiftBeanCountParser/Parser.swift` - Contains `parse(contentOf:)` and `parse(string:)` methods
- **Individual parsers**: `Sources/SwiftBeanCountParser/*Parser.swift` - Handle specific BeanCount constructs
- **Test files**: `Tests/SwiftBeanCountParserTests/` - All tests use XCTest framework
- **Sample BeanCount files**: `Tests/SwiftBeanCountParserTests/Resources/` - Use these for testing and validation
- **Package definition**: `Package.swift` - Swift Package Manager configuration
- **CI configuration**: `.github/workflows/ci.yml` - Build, test, lint pipeline

### Understanding BeanCount Format
BeanCount files use plain text format for double-entry bookkeeping. Example from `Minimal.beancount`:
```
2017-06-08 commodity EUR
2017-06-08 open Equity:OpeningBalance
2017-06-08 open Assets:Checking
2017-06-08 * "Payee" "Narration"
  Equity:OpeningBalance -1.00 EUR
  Assets:Checking 1.00 EUR
```

### Making Parser Changes
- **Always test with existing Resources**: Use test files like `Big.beancount` for comprehensive testing
- **Run performance tests**: Several tests include performance measurements - ensure these don't regress
- **Test error handling**: Files like `InvalidCost.beancount` test error scenarios
- **Check round-trip parsing**: The test suite includes round-trip tests that parse → serialize → parse again

### Dependencies
The library depends on:
- `SwiftBeanCountModel` - Data models for parsed objects
- `SwiftBeanCountParserUtils` - Utility functions for parsing

For exact versions and constraints, check `Package.swift` in the repository root.

### Common Issues
- **Build errors**: Usually resolved by clean build: `rm -rf .build && swift build`
- **Test failures**: Check that sample files in Resources/ are valid BeanCount format
- **Linting failures**: Run `./swiftlint/swiftlint --strict` and fix reported issues
- **Coverage issues**: CI enforces minimum coverage thresholds defined in `.github/minimum_coverage.txt`

## Exact Commands Reference

### Setup (run once)

Install SwiftLint:
Check instructions in .github/ci.yml under the "SwiftLint" action, "Install SwiftLint" step, to see how to curl and unzip the correct version of swiftlint. Ensure to use the exact version mentioned in ci.yml

### Development Workflow (run before every commit)
```bash
# Clean build (if needed)
rm -rf .build

# Build library (NEVER CANCEL - timeout 3 minutes)
swift build

# Run all tests (NEVER CANCEL - timeout 3 minutes)
swift test

# Run linting (NEVER CANCEL - timeout 1 minute)
./swiftlint/swiftlint --strict

# Run tests with coverage for CI validation (NEVER CANCEL - timeout 3 minutes)
swift test --enable-code-coverage
```

**IMPORTANT**: Each commit must be accompanied with proper tests that validate the changes made.
