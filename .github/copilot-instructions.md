# GitHub Copilot Instructions for SwiftBeanCount

## Project Overview

SwiftBeanCount is a double-entry accounting software written in Swift, inspired by [beancount](https://github.com/beancount/beancount). It reads and writes plain text accounting files and aims to be compatible with beancount's syntax (as a subset).

This is a learning and personal project focused on:
- Learning and practicing Swift
- Learning SwiftUI
- Native macOS development
- GitHub Actions experience
- Test-Driven Development (TDD)

## Swift Standards

### Language Version
- Use Swift 6.2.3
- Target platforms: macOS 13+ and iOS 16+
- Use Swift 5 language mode (`.swiftLanguageMode(.v5)`)

### Code Quality
- **All warnings are treated as errors** (`.treatAllWarnings(as: .error)`)
- Use SwiftLint for linting - strict mode is enabled
- Follow all SwiftLint rules configured in `.swiftlint.yml`
- Pay special attention to the extensive list of opt-in rules enabled in the project

### Naming Conventions
- Use descriptive, clear names for types, functions, and variables
- Follow Swift API design guidelines
- Use camelCase for properties, methods, and variables
- Use PascalCase for types (structs, classes, enums, protocols)
- Enum cases should use camelCase

### Documentation
- Use triple-slash (`///`) comments for documentation
- Document all public APIs
- Include parameter descriptions for functions
- Include return value descriptions
- Use markdown formatting in documentation comments
- Example:
  ```swift
  /// Gets all types
  ///
  /// - Returns: `Array` with all five AccountTypes
  public static func allValues() -> [Self] {
  ```

## Testing Requirements

### Test-Driven Development (TDD)
- **Write tests before implementing features**
- Follow TDD practices as this is a core learning goal of the project

### Testing Framework
- Use XCTest for all tests
- Import modules with `@testable import ModuleName` in test files
- Test files should be named with `Tests` suffix (e.g., `AccountTests.swift`)

### Test Coverage
- High test coverage is required and enforced in CI
- Minimum coverage threshold is defined in `.github/minimum_coverage.txt`
- CI will fail if coverage drops below the threshold
- Coverage reports are generated using `llvm-cov`

### Test Structure
- Use descriptive test function names starting with `test` prefix
- Use `XCTAssert` family of assertions
- Group related tests in the same test class
- Use `final` for test classes

## Project Structure

### Multi-Package Organization
The project is organized into multiple Swift packages:

**Core Libraries:**
- `SwiftBeanCountModel`: Data model and business logic
- `SwiftBeanCountParser`: Plain text parser
- `SwiftBeanCountParserUtils`: Shared parsing utilities

**Domain-Specific Mappers:**
- `SwiftBeanCountRogersBankMapper`
- `SwiftBeanCountCompassCardMapper`
- `SwiftBeanCountTangerineMapper`
- `SwiftBeanCountWealthsimpleMapper`

**Other Libraries:**
- `SwiftBeanCountImporter`: CSV and text import functionality
- `SwiftBeanCountTax`: Tax calculation utilities
- `SwiftBeanCountSheetSync`: Google Sheets synchronization
- `SwiftBeanCountStatements`: Statement handling

**Executables:**
- `SwiftBeanCountCLI`: Command-line interface

### File Organization
- Each module should have its own directory under `Sources/`
- Each module has corresponding test directory under `Tests/`
- README.md files may exist in module directories (excluded from compilation)
- All modules use SwiftLint build plugin

## Coding Conventions

### General Guidelines
- Keep function bodies concise (max 30 lines by default)
- Keep line length reasonable (warning at 175 characters)
- Use implicit returns where appropriate (opt-in rule enabled)
- Sort imports alphabetically
- Use sorted first/last instead of first where appropriate
- Prefer `self` type over `type(of: self)`

### Error Handling
- Use proper error types and handle errors appropriately
- Use typed errors in catch blocks (avoid untyped errors)
- Document errors that can be thrown

### Collections and Optionals
- Use `isEmpty` instead of `count == 0` (empty_count rule)
- Discourage optional booleans and optional collections
- Use `contains` over filter operations where appropriate

### Type Safety
- Avoid force unwrapping where possible
- Use proper optional handling
- Use strong typing throughout

### Access Control
- Use appropriate access control levels (public, internal, private, fileprivate)
- Use strict fileprivate (prefer private where possible)
- Document public APIs comprehensively

## Compatibility with beancount

### Supported Syntax
- SwiftBeanCount syntax should be a **subset** of beancount syntax
- Users should be able to use the same plain text files with both tools

### NOT Supported in SwiftBeanCount
Do not implement or suggest features that are not supported:
- Dates with slashes (use dashes only)
- "txn" flag (use * or ! instead)
- Flags on postings
- Optional pipe between payee and narration
- Leaving out payee/narration fields
- Amount interpolation
- Inline math
- Links
- Pad directive
- Documents directive
- Options directive
- Notes directive
- Includes
- Plugins
- Tag stacks
- Balance checks on parent accounts
- Accounts with multiple commodities

### SwiftBeanCount Extensions
Be cautious when using features that beancount doesn't support:
- Full Unicode support (use carefully, may break beancount compatibility)
- Commodities with more than 24 characters (avoid)

## Build and CI

### Building
- Use Swift Package Manager (SPM)
- Build command: `swift build`
- Test command: `swift test --enable-code-coverage`

### Continuous Integration
- CI runs on macOS, Ubuntu, and iOS platforms
- SwiftLint runs as part of the build process
- Test coverage is enforced
- GitHub Actions workflows are in `.github/workflows/`

## General Principles

1. **Minimal Changes**: Make the smallest possible changes to accomplish the goal
2. **Test First**: Write tests before implementation (TDD)
3. **Documentation**: Document all public APIs thoroughly
4. **Type Safety**: Leverage Swift's type system for safety
5. **Compatibility**: Keep syntax compatible with beancount where possible
6. **Code Quality**: Maintain strict SwiftLint compliance
7. **Coverage**: Maintain or improve test coverage with every change
