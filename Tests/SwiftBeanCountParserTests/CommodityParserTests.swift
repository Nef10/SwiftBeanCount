//
//  CommodityParserTests.swift
//  SwiftBeanCountParserTests
//
//  Created by Steffen Kötte on 2019-07-25.
//  Copyright © 2019 Steffen Kötte. All rights reserved.
//

import Foundation
import SwiftBeanCountModel
@testable import SwiftBeanCountParser
import Testing

@Suite
struct CommodityParserTests {

    private let basicString = "2017-06-09 commodity CAD"
    private let whitespaceString = "2017-06-09    commodity        CAD"
    private let endOfLineCommentString = "2017-06-09 commodity CAD ;gfsdt     "
    private let specialCharacterString = "2017-06-09 commodity CAD💵"
    private let invalidDateString = "2017-02-30 commodity CAD"

   @Test
   func testBasic() {
        let commodity = CommodityParser.parseFrom(line: basicString)
        #expect(commodity == Commodity(symbol: "CAD", opening: TestUtils.date20170609))
    }

   @Test
   func testWhitespace() {
        let commodity = CommodityParser.parseFrom(line: whitespaceString)
        #expect(commodity == Commodity(symbol: "CAD", opening: TestUtils.date20170609))
    }

   @Test
   func testEndOfLineComment() {
        let commodity = CommodityParser.parseFrom(line: endOfLineCommentString)
        #expect(commodity == Commodity(symbol: "CAD", opening: TestUtils.date20170609))
    }

   @Test
   func testSpecialCharacter() {
        let commodity = CommodityParser.parseFrom(line: specialCharacterString)
        #expect(commodity == Commodity(symbol: "CAD💵", opening: TestUtils.date20170609))
    }

   @Test
   func testInvalidCloseDate() {
        let commodity = CommodityParser.parseFrom(line: invalidDateString)
        #expect(commodity == nil)
    }

}
