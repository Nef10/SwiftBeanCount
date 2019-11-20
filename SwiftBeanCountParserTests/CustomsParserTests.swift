//
//  CustomsParserTests.swift
//  SwiftBeanCountParserTests
//
//  Created by Koette, Steffen on 2019-11-20.
//  Copyright © 2019 Steffen Kötte. All rights reserved.
//

import SwiftBeanCountModel
@testable import SwiftBeanCountParser
import XCTest

class CustomsParserTests: XCTestCase {

    let basicString = "2017-06-09 custom \"ABC\" \"DEF\""
    let multipleValuesString = "2017-06-09 custom \"ABC\" \"DEF\" \"GHI\" \"JKL\" \"MNO\""
    let whitespaceString = "2017-06-09 custom    \"ABC\"       \"DEF\"      \"GHI\"       "
    let endOfLineCommentString = "2017-06-09 custom \"ABC\" \"DEF\"  \"GHI\";gfsdt     "
    let specialCharacterString = "2017-06-09 custom \"ABC💵\" \"DEF💵\" \"GHI💵\""
    let invalidDateString = "2017-02-30 custom \"ABC\" \"DEF\""

    func testBasic() {
        let event = CustomsParser.parseFrom(line: basicString)!
        XCTAssertEqual(event.date, TestUtils.date20170609)
        XCTAssertEqual(event.name, "ABC")
        XCTAssertEqual(event.values, ["DEF"])
    }

    func testMultipleValues() {
        let event = CustomsParser.parseFrom(line: multipleValuesString)!
        XCTAssertEqual(event.date, TestUtils.date20170609)
        XCTAssertEqual(event.name, "ABC")
        XCTAssertEqual(event.values, ["DEF", "GHI", "JKL", "MNO"])
    }

    func testWhitespace() {
        let event = CustomsParser.parseFrom(line: whitespaceString)!
        XCTAssertEqual(event.date, TestUtils.date20170609)
        XCTAssertEqual(event.name, "ABC")
        XCTAssertEqual(event.values, ["DEF", "GHI"])
    }

    func testEndOfLineComment() {
        let event = CustomsParser.parseFrom(line: endOfLineCommentString)!
        XCTAssertEqual(event.date, TestUtils.date20170609)
        XCTAssertEqual(event.name, "ABC")
        XCTAssertEqual(event.values, ["DEF", "GHI"])
    }

    func testSpecialCharacter() {
        let event = CustomsParser.parseFrom(line: specialCharacterString)!
        XCTAssertEqual(event.date, TestUtils.date20170609)
        XCTAssertEqual(event.name, "ABC💵")
        XCTAssertEqual(event.values, ["DEF💵", "GHI💵"])
    }

    func testInvalidDate() {
        XCTAssertNil(CustomsParser.parseFrom(line: invalidDateString))
    }

    func testPerformance() {
        self.measure {
            for _ in 0...1_000 {
                _ = CustomsParser.parseFrom(line: basicString)
                _ = CustomsParser.parseFrom(line: multipleValuesString)
                _ = CustomsParser.parseFrom(line: whitespaceString)
                _ = CustomsParser.parseFrom(line: endOfLineCommentString)
                _ = CustomsParser.parseFrom(line: specialCharacterString)
            }
        }
    }

}
