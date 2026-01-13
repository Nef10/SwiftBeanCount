# GitHub Copilot Instructions for SwiftBeanCount

## Project Overview

SwiftBeanCount is a double-entry accounting software written in Swift, inspired by [beancount](https://github.com/beancount/beancount). It reads and writes plain text accounting files and aims to be compatible with beancount's syntax (as a subset).

**Key Facts:**
- Multi-package Swift project with 12+ modules
- Supports macOS 13+, iOS 16+
- Uses very new Swift with strict compiler settings
- Zero-tolerance for warnings (all warnings are errors in CI)
- Requires very high (around 90%) minimum test coverage
- Uses SwiftLint with 100+ rules enabled

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
- MUST pass before submitting code

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

## Dependencies and Package Management

### Adding Dependencies
- Use Swift Package Manager (SPM) for all dependencies
- Pin to specific versions for stability when appropriate
- Document why each dependency is needed
- Check for security vulnerabilities before adding new dependencies
- Keep dependencies up to date via automated workflows

### Dependency Structure
- External dependencies defined in `Package.swift`
- Internal dependencies follow the module structure
- Avoid circular dependencies between modules
- Keep dependencies minimal and focused

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
5. Ensure all changes are minimal and focused

### Making Changes
- **Make minimal modifications** - change only what's necessary
- Focus on the specific issue or feature
- Don't refactor unrelated code
- Don't fix unrelated bugs or broken tests
- Keep changes surgical and precise
- Update documentation if directly related to changes

### Validation Steps - Always Run Before Committing
1. `swift build` - ensures compilation succeeds, MUST pass (timeout: 300s)
2. `swift test` - ensures all tests pass, MUST pass (timeout: 300s)
3. `./swiftlint/swiftlint --strict --reporter github-actions-logging` - ensures code style compliance, MUST pass (timeout: 60s)

### Before Submitting
1. Run all validation steps (build, test, lint)
2. Verify test coverage hasn't decreased
3. Check that changes are minimal and focused
4. Ensure no secrets or sensitive data are committed
5. Review git diff to confirm only intended changes

### Common Pitfalls to Avoid
- **Never** reduce test coverage below the threshold in `.github/minimum_coverage.txt`
- **Never** ignore or skip failing tests - all tests must pass
- **Never** commit code with warnings - they are treated as errors
- **Never** cancel long-running build/test commands - they need time to complete
- **Never** use force push - rebasing is not allowed in this workflow
- **Never** modify `.github/agents/` directory - contains instructions for other agents

## Continuous Integration

### CI Pipeline
- Runs on every pull request and push to main
- Tests on macOS, Ubuntu, and iOS platforms
- Uses very new Swift (check `.github/workflows/ci.yml` for exact version)
- Enforces high code coverage minimum 
- Runs SwiftLint in strict mode
- All checks must pass before merge

### Handling CI Failures
- Check GitHub Actions logs for detailed error messages
- Build failures: ensure code compiles locally first
- Test failures: run `swift test` locally to debug
- Lint failures: run SwiftLint locally and fix issues
- Coverage failures: add tests to meet minimum threshold
- Don't ignore or skip failing tests to make CI pass

## Troubleshooting

### Build Issues
- Ensure Swift version matches CI requirements
- Clean build: `swift package clean`
- Reset package: `rm -rf .build && swift package resolve`
- Check for missing dependencies

### Test Issues
- Run specific test: `swift test --filter <TestName>`
- Enable verbose output: `swift test --verbose`
- Check test resources are properly included

### Linting Issues
- Auto-fix when possible: SwiftLint can fix many issues automatically
- Review SwiftLint configuration in `.swiftlint.yml`
- Never disable rules
- Follow existing code patterns

## Code Quality Standards

### Error Handling
- Use proper Swift error handling with `throws` and `do-catch`
- Create custom error types for domain-specific errors (see existing `*Error.swift` files)
- Document errors that can be thrown in function documentation
- Validate inputs early and fail fast with clear error messages

### Testing Requirements
- Write tests for all new functionality
- Follow existing test patterns in the `Tests/` directory
- Test files should mirror source file structure
- Use descriptive test names that explain what is being tested
- Aim for high test coverage (minimum 82% required)
- Test both success and failure cases
- Test edge cases and boundary conditions

### Code Style
- Follow Swift API Design Guidelines
- Use explicit types when clarity is needed
- Prefer `let` over `var` when possible
- Use meaningful variable and function names
- Keep functions focused and single-purpose
- Avoid force unwrapping (`!`) unless absolutely safe
- Use guard statements for early returns

### Security Best Practices
- Never commit secrets, API keys, or credentials
- Validate and sanitize all external inputs
- Use secure coding practices for file I/O operations
- Be cautious with force unwrapping optional values
- Follow principle of least privilege in code design
