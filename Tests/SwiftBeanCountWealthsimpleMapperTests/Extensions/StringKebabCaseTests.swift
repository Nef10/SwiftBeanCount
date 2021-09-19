@testable import SwiftBeanCountWealthsimpleMapper
import XCTest

final class StringKebabCaseTests: XCTestCase {

    func testCamelCaseToKebabCase() {
        XCTAssertEqual("TEST123".camelCaseToKebabCase(), "test-123")
        XCTAssertEqual("TEST1Test".camelCaseToKebabCase(), "test-1-test")
        XCTAssertEqual("EURTest".camelCaseToKebabCase(), "eur-test")
        XCTAssertEqual("ThisIsATest".camelCaseToKebabCase(), "this-is-a-test")
        XCTAssertEqual("1234ThisIsATest".camelCaseToKebabCase(), "1234-this-is-a-test")
        XCTAssertEqual("test123".camelCaseToKebabCase(), "test-123")
        XCTAssertEqual("test".camelCaseToKebabCase(), "test")
        XCTAssertEqual("123".camelCaseToKebabCase(), "123")
        XCTAssertEqual("".camelCaseToKebabCase(), "")
    }

}
