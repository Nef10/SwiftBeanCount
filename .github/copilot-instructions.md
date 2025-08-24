# SwiftBeanCountModel

SwiftBeanCountModel is a Swift Package Manager library providing core data models and business logic for BeanCount ledger accounting systems. This is a pure library with no executable application - it only provides Swift types and validation logic for financial ledger operations.

Always reference these instructions first and fallback to search or bash commands only when you encounter unexpected information that does not match the info here.

## Working Effectively

### Bootstrap and Build
- Install Swift if not available: `curl -s https://swift.org/install/install.sh | bash` or use swift-actions/setup-swift@v2.3.0
- Build the library: `swift build` - takes ~6-18 seconds. NEVER CANCEL. Set timeout to 60+ seconds.
- The build produces no executable - this is a library only

### Testing
- Run all tests: `swift test --enable-code-coverage -Xswiftc -warnings-as-errors` - takes ~7 seconds, runs 213 tests. NEVER CANCEL. Set timeout to 60+ seconds.
- Test coverage requirement: 98% minimum (enforced by CI)
- Tests include comprehensive validation of all financial models and business logic
- All tests MUST pass - no skipping or ignoring failed tests

### Linting
- Install SwiftLint: `curl -L https://github.com/realm/SwiftLint/releases/download/0.59.1/swiftlint_linux.zip -o swiftlint.zip && unzip swiftlint.zip -d swiftlint`
- Run SwiftLint: `./swiftlint/swiftlint --strict --reporter github-actions-logging` - takes ~4 seconds. NEVER CANCEL. Set timeout to 30+ seconds.
- CRITICAL: SwiftLint runs in strict mode with zero tolerance for violations
- The project uses extensive SwiftLint rules (100+ enabled) for code quality

## Validation

### Always Run Before Committing
1. `swift build` - ensures compilation succeeds
2. `swift test --enable-code-coverage -Xswiftc -warnings-as-errors` - ensures all tests pass with required coverage
3. `./swiftlint/swiftlint --strict --reporter github-actions-logging` - ensures code style compliance

### CRITICAL Build Requirements
- **NEVER CANCEL long-running operations**: All builds and tests must complete fully
- **Build timeout**: Set 60+ seconds minimum for swift build
- **Test timeout**: Set 60+ seconds minimum for swift test  
- **Lint timeout**: Set 30+ seconds minimum for SwiftLint
- **Warnings as errors**: All Swift compilation warnings are treated as build failures

### Platform Support
- Supports: macOS (latest), Linux (Ubuntu latest)
- Swift version: 5.2+ required (currently tested with 6.1+)
- No iOS app or executable - pure Swift Package Manager library

## Common Tasks

### Key Project Structure
```
SwiftBeanCountModel/
├── Sources/SwiftBeanCountModel/     # 19 Swift model files
│   ├── Account.swift               # Account management and validation
│   ├── Amount.swift                # Currency amounts
│   ├── Ledger.swift                # Main ledger coordination
│   ├── Transaction.swift           # Financial transactions
│   └── ...                         # Other model types
├── Tests/SwiftBeanCountModelTests/  # 18 test files with 213 tests
├── Package.swift                   # Swift Package Manager config
├── .swiftlint.yml                  # Comprehensive linting rules
└── .github/workflows/ci.yml        # CI pipeline
```

### Development Workflow
1. Make code changes to Sources/ directory
2. Update corresponding tests in Tests/ directory if needed
3. Run validation steps (build, test, lint)
4. Ensure 98% test coverage is maintained
5. All tests must pass - no skipping or ignoring failing tests

### Configuration Files
- `.swiftlint.yml`: 100+ enabled rules, strict enforcement
- `.github/minimum_coverage.txt`: Contains "98" (minimum coverage %)
- `.jazzy.yaml`: Documentation generation (requires Ruby gems)
- Package.swift: Swift Package Manager configuration

### Important Directories
- `Sources/SwiftBeanCountModel/`: All library implementation
- `Tests/SwiftBeanCountModelTests/`: All test code
- `.github/workflows/`: CI/CD pipeline definitions
- `.build/`: Build artifacts (auto-generated, gitignored)

### Common Error Patterns
- SwiftLint violations: Run `./swiftlint/swiftlint` to see specific issues
- Test coverage below 98%: Add tests for uncovered code paths
- Build warnings: Fix all warnings as they become errors with `-Xswiftc -warnings-as-errors`
- Missing SwiftLint binary: Re-download with curl command above

### Documentation
- Main docs: README.md and inline Swift documentation
- API docs can be generated with jazzy (requires Ruby gems installation)
- No user-facing application documentation - this is a library

## Repository Context

### Project Purpose
This library provides Swift data models for double-entry bookkeeping systems compatible with BeanCount. Key model types include:
- Accounts with validation and balance tracking
- Transactions with automatic balancing
- Commodities and exchange rates
- Inventory management with lot tracking
- Custom directives and metadata

### Manual Validation of Library Functionality
Since this is a library with no executable, validate basic functionality by examining test files:
```bash
# Look at sample usage in existing tests
head -20 Tests/SwiftBeanCountModelTests/LedgerTests.swift
```
The test files demonstrate proper usage patterns. You can also verify the library builds correctly by checking that `swift build` completes without errors and that the main types are available.

### CI Pipeline Validation
The GitHub Actions CI runs on both macOS and Linux and enforces:
- Successful compilation on both platforms
- All 213 tests pass
- 98% minimum test coverage
- Zero SwiftLint violations in strict mode
- Warnings treated as compilation errors