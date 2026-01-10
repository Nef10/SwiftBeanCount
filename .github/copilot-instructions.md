# GitHub Copilot Instructions for SwiftBeanCount

## Project Overview

SwiftBeanCount is a double-entry accounting software written in Swift, inspired by [beancount](https://github.com/beancount/beancount). It reads and writes plain text accounting files and aims to be compatible with beancount's syntax (as a subset).

## Working Effectively

### Bootstrap and Build
- Install Swift if not available: `curl -s https://swift.org/install/install.sh | bash` or use swift-actions/setup-swift@v3
- Usually leverages newest Swift version - Check .github/workflows/ci.yml ONLY if required for exact version because of errors
- Build the library: `swift build` - NEVER CANCEL. Set timeout to 300 seconds.
- **All warnings are treated as errors** (`.treatAllWarnings(as: .error)`)

### Testing
- Run all tests: `swift test` NEVER CANCEL. Set timeout to 300 seconds.
- All tests MUST pass before submitting code - no skipping or ignoring failed tests
- High test coverage is required and enforced in CI
- Minimum coverage threshold is defined in `.github/minimum_coverage.txt`
- CI will fail if coverage drops below the threshold

### Linting
- Use SwiftLint for linting - runs in strict mode with zero tolerance for warnings
- Install SwiftLint: `curl -L https://github.com/realm/SwiftLint/releases/download/0.59.1/swiftlint_linux.zip -o swiftlint.zip && unzip swiftlint.zip -d swiftlint`
- Run SwiftLint: `./swiftlint/swiftlint --strict --reporter github-actions-logging` - NEVER CANCEL. Set timeout to 60 seconds.
- The project uses extensive SwiftLint rules (100+ enabled) for code quality
- MUST pass before submiting code

## Swift Standards

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

### DocC Documentation
- Each module has its own `.docc` documentation catalog under `Sources/<ModuleName>/<ModuleName>.docc/`
- The main documentation file is `<ModuleName>.md` within each catalog
- Build documentation for a specific target: `swift package plugin generate-documentation --target <TargetName>`
- Preview documentation: `swift package plugin preview-documentation --target <TargetName>`
- All modules use DocC for comprehensive documentation generation
- Update the documentation catalog as required

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

## Development

### Workflow
1. Make code changes to Sources/ directory
2. Update corresponding tests in Tests/ directory if required
3. Create new Tests if required
4. Run validation steps

### Validation Steps - Always Run Before Committing
1. `swift build` - ensures compilation succeeds, MUST pass
2. `swift test` - ensures all tests pass, MUST pass
3. `swiftlint` - ensures code style compliance, MUST pass
