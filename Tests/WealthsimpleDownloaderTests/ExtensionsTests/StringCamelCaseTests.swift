//
//  StringCamelCaseTests.swift
//
//
//  Created by Steffen Kötte on 2021-09-15.
//

import Foundation
import Testing
@testable import WealthsimpleDownloader

@Suite(.serialized)
final class StringCamelCaseTests {

    @Test
    func testCamelCase() {
        expectEqual("".camelCase, "")

        expectEqual("ABC".camelCase, "aBC")
        expectEqual("abc".camelCase, "abc")
        expectEqual("aBc".camelCase, "aBc")

        expectEqual("abc def".camelCase, "abcDef")
        expectEqual("ABC DEF".camelCase, "aBCDEF")
        expectEqual("aBc dEf".camelCase, "aBcDEf")

        expectEqual("abc def ghi jkl".camelCase, "abcDefGhiJkl")
        expectEqual("a b c d e".camelCase, "aBCDE")

        expectEqual("a1a b c3c d e4e".camelCase, "a1aBC3cDE4e")

        expectEqual("abc-def&ghi+jkl%mno_pqr".camelCase, "abcDefGhiJklMnoPqr")
    }

}
