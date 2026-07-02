import Foundation
import Testing

final class XCTestExpectation: @unchecked Sendable {

    let description: String
    private let semaphore = DispatchSemaphore(value: 0)

    init(description: String) {
        self.description = description
    }

    func fulfill() {
        semaphore.signal()
    }

    @discardableResult
    func wait(timeout: TimeInterval) -> Bool {
        semaphore.wait(timeout: .now() + timeout) == .success
    }
}

func wait(for expectations: [XCTestExpectation], timeout: TimeInterval, sourceLocation: SourceLocation = #_sourceLocation) {
    for expectation in expectations where !expectation.wait(timeout: timeout) {
        Issue.record("Timed out waiting for expectation: \(expectation.description)", sourceLocation: sourceLocation)
    }
}

func XCTFail(_ message: @autoclosure () -> String = "", sourceLocation: SourceLocation = #_sourceLocation) {
    Issue.record(message(), sourceLocation: sourceLocation)
}

func XCTAssert(_ expression: @autoclosure () -> Bool, sourceLocation: SourceLocation = #_sourceLocation) {
    #expect(expression(), sourceLocation: sourceLocation)
}

func XCTAssertTrue(_ expression: @autoclosure () -> Bool, sourceLocation: SourceLocation = #_sourceLocation) {
    #expect(expression(), sourceLocation: sourceLocation)
}

func XCTAssertFalse(_ expression: @autoclosure () -> Bool, sourceLocation: SourceLocation = #_sourceLocation) {
    #expect(!expression(), sourceLocation: sourceLocation)
}

func XCTAssertEqual<T: Equatable>(_ expression1: @autoclosure () -> T, _ expression2: @autoclosure () -> T, sourceLocation: SourceLocation = #_sourceLocation) {
    #expect(expression1() == expression2(), sourceLocation: sourceLocation)
}

func XCTAssertNotEqual<T: Equatable>(_ expression1: @autoclosure () -> T, _ expression2: @autoclosure () -> T, sourceLocation: SourceLocation = #_sourceLocation) {
    #expect(expression1() != expression2(), sourceLocation: sourceLocation)
}

func XCTAssertNil<T>(_ expression: @autoclosure () -> T?, sourceLocation: SourceLocation = #_sourceLocation) {
    #expect(expression() == nil, sourceLocation: sourceLocation)
}

func XCTAssertNotNil<T>(_ expression: @autoclosure () -> T?, sourceLocation: SourceLocation = #_sourceLocation) {
    #expect(expression() != nil, sourceLocation: sourceLocation)
}

func XCTAssertIdentical(_ expression1: @autoclosure () -> AnyObject?, _ expression2: @autoclosure () -> AnyObject?, sourceLocation: SourceLocation = #_sourceLocation) {
    #expect(expression1() === expression2(), sourceLocation: sourceLocation)
}

@discardableResult
func XCTAssertNoThrow<T>(_ expression: @autoclosure () throws -> T, sourceLocation: SourceLocation = #_sourceLocation) -> T? {
    do {
        return try expression()
    } catch {
        Issue.record("Expected no throw, but received: \(error)", sourceLocation: sourceLocation)
        return nil
    }
}

func XCTAssertThrowsError<T>(_ expression: @autoclosure () throws -> T, sourceLocation: SourceLocation = #_sourceLocation, _ handler: ((Error) -> Void)? = nil) {
    do {
        _ = try expression()
        Issue.record("Expected expression to throw an error", sourceLocation: sourceLocation)
    } catch {
        handler?(error)
    }
}

enum UnwrapError: Error {
    case nilValue
}

func XCTUnwrap<T>(_ expression: @autoclosure () -> T?, sourceLocation: SourceLocation = #_sourceLocation) throws -> T {
    guard let value = expression() else {
        Issue.record("Expected non-nil value", sourceLocation: sourceLocation)
        throw UnwrapError.nilValue
    }
    return value
}

func assert<T, E: Error & Equatable>(
    _ expression: @autoclosure () throws -> T,
    throws expectedError: E,
    sourceLocation: SourceLocation = #_sourceLocation
) {
    var caughtError: Error?
    XCTAssertThrowsError(try expression(), sourceLocation: sourceLocation) {
        caughtError = $0
    }

    guard let error = caughtError as? E else {
        let errorType = caughtError.map { String(describing: type(of: $0)) } ?? "nil"
        Issue.record("Unexpected error type, got \(errorType) instead of \(E.self)", sourceLocation: sourceLocation)
        return
    }

    #expect(error == expectedError, sourceLocation: sourceLocation)
}
