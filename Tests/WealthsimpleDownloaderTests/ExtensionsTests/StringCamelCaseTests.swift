//
//  StringCamelCaseTests.swift
//
//
//  Created by Steffen Kötte on 2021-09-15.
//

import Foundation
import Testing
@testable import WealthsimpleDownloader

@Suite
final class StringCamelCaseTests {

    @Test
    func testCamelCase() {
        XCTAssertEqual("".camelCase, "")

        XCTAssertEqual("ABC".camelCase, "aBC")
        XCTAssertEqual("abc".camelCase, "abc")
        XCTAssertEqual("aBc".camelCase, "aBc")

        XCTAssertEqual("abc def".camelCase, "abcDef")
        XCTAssertEqual("ABC DEF".camelCase, "aBCDEF")
        XCTAssertEqual("aBc dEf".camelCase, "aBcDEf")

        XCTAssertEqual("abc def ghi jkl".camelCase, "abcDefGhiJkl")
        XCTAssertEqual("a b c d e".camelCase, "aBCDE")

        XCTAssertEqual("a1a b c3c d e4e".camelCase, "a1aBC3cDE4e")

        XCTAssertEqual("abc-def&ghi+jkl%mno_pqr".camelCase, "abcDefGhiJklMnoPqr")
    }

}
