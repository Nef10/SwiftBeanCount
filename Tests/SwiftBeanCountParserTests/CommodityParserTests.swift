//
//  CommodityParserTests.swift
//  SwiftBeanCountParserTests
//
//  Created by Steffen Kötte on 2019-07-25.
//  Copyright © 2019 Steffen Kötte. All rights reserved.
//

import SwiftBeanCountModel
@testable import SwiftBeanCountParser
import XCTest

class CommodityParserTests: XCTestCase {

    let basicString = "2017-06-09 commodity CAD"
    let whitespaceString = "2017-06-09    commodity        CAD"
    let endOfLineCommentString = "2017-06-09 commodity CAD ;gfsdt     "
    let specialCharacterString = "2017-06-09 commodity CAD💵"
    let invalidDateString = "2017-02-30 commodity CAD"

    func testBasic() {
        let commodity = CommodityParser.parseFrom(line: basicString)
        XCTAssertEqual(commodity, Commodity(symbol: "CAD", opening: TestUtils.date20170609))
    }

    func testWhitespace() {
        let commodity = CommodityParser.parseFrom(line: whitespaceString)
        XCTAssertEqual(commodity, Commodity(symbol: "CAD", opening: TestUtils.date20170609))
    }

    func testEndOfLineComment() {
        let commodity = CommodityParser.parseFrom(line: endOfLineCommentString)
        XCTAssertEqual(commodity, Commodity(symbol: "CAD", opening: TestUtils.date20170609))
    }

    func testSpecialCharacter() {
        let commodity = CommodityParser.parseFrom(line: specialCharacterString)
        XCTAssertEqual(commodity, Commodity(symbol: "CAD💵", opening: TestUtils.date20170609))
    }

    func testInvalidCloseDate() {
        let commodity = CommodityParser.parseFrom(line: invalidDateString)
        XCTAssertNil(commodity)
    }

    func testPerformance() {
        self.measure {
            for _ in 0...1_000 {
                _ = CommodityParser.parseFrom(line: basicString)
                _ = CommodityParser.parseFrom(line: whitespaceString)
                _ = CommodityParser.parseFrom(line: endOfLineCommentString)
                _ = CommodityParser.parseFrom(line: specialCharacterString)
            }
        }
    }

}
