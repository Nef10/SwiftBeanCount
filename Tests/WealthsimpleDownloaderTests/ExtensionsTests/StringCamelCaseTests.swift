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
   func camelCase() {
       #expect("".camelCase.isEmpty)
       #expect("ABC".camelCase == "aBC")
       #expect("abc".camelCase == "abc")
       #expect("aBc".camelCase == "aBc")
       #expect("abc def".camelCase == "abcDef")
       #expect("ABC DEF".camelCase == "aBCDEF")
       #expect("aBc dEf".camelCase == "aBcDEf")
       #expect("abc def ghi jkl".camelCase == "abcDefGhiJkl")
       #expect("a b c d e".camelCase == "aBCDE")
       #expect("a1a b c3c d e4e".camelCase == "a1aBC3cDE4e")
       #expect("abc-def&ghi+jkl%mno_pqr".camelCase == "abcDefGhiJklMnoPqr")
   }
}
