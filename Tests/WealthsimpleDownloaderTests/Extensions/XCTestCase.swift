import Foundation
import XCTest

extension XCTestCase {

    func assert<T, E: Error & Equatable>(_ expression: @autoclosure () throws -> T, throws expectedError: E, in file: StaticString = #file, line: UInt = #line) {
        var caughtError: Error?

        XCTAssertThrowsError(try expression(), file: file, line: line) {
            caughtError = $0
        }

        guard let error = caughtError as? E else {
            XCTFail("Unexpected error type, got \(type(of: caughtError!)) instead of \(E.self)", file: file, line: line)
            return
        }

        XCTAssertEqual(error, expectedError, file: file, line: line)
    }

}
