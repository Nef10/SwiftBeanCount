

import Foundation
@testable import SwiftBeanCountWealthsimpleMapper
import Testing

@Suite

struct StringKebabCaseTests {

   @Test
   func testCamelCaseToKebabCase() {
        #expect("TEST123".camelCaseToKebabCase() == "test-123")
        #expect("TEST1Test".camelCaseToKebabCase() == "test-1-test")
        #expect("EURTest".camelCaseToKebabCase() == "eur-test")
        #expect("ThisIsATest".camelCaseToKebabCase() == "this-is-a-test")
        #expect("1234ThisIsATest".camelCaseToKebabCase() == "1234-this-is-a-test")
        #expect("test123".camelCaseToKebabCase() == "test-123")
        #expect("test".camelCaseToKebabCase() == "test")
        #expect("123".camelCaseToKebabCase() == "123")
        #expect("".camelCaseToKebabCase() == "")
    }

}
