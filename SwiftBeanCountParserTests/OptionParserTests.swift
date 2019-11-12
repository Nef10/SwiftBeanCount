//
//  OptionParserTests.swift
//  SwiftBeanCountParserTests
//
//  Created by Steffen Kötte on 2019-11-11.
//  Copyright © 2019 Steffen Kötte. All rights reserved.
//

import SwiftBeanCountModel
@testable import SwiftBeanCountParser
import XCTest

class OptionParserTests: XCTestCase {

    let basicString = "option \"ABC\" \"DEF\""
    let whitespaceString = "option    \"ABC\"       \"DEF\"     "
    let endOfLineCommentString = "option \"ABC\" \"DEF\";gfsdt     "
    let specialCharacterString = "option \"ABC💵\" \"DEF💵\""

    func testBasic() {
        let (option, value) = OptionParser.parseFrom(line: basicString)!
        XCTAssertEqual(option, "ABC")
        XCTAssertEqual(value, "DEF")
    }

    func testWhitespace() {
        let (option, value) = OptionParser.parseFrom(line: whitespaceString)!
        XCTAssertEqual(option, "ABC")
        XCTAssertEqual(value, "DEF")
    }

    func testEndOfLineComment() {
        let (option, value) = OptionParser.parseFrom(line: endOfLineCommentString)!
        XCTAssertEqual(option, "ABC")
        XCTAssertEqual(value, "DEF")
    }

    func testSpecialCharacter() {
        let (option, value) = OptionParser.parseFrom(line: specialCharacterString)!
        XCTAssertEqual(option, "ABC💵")
        XCTAssertEqual(value, "DEF💵")
    }

    func testPerformance() {
        self.measure {
            for _ in 0...1_000 {
                _ = OptionParser.parseFrom(line: basicString)
                _ = OptionParser.parseFrom(line: whitespaceString)
                _ = OptionParser.parseFrom(line: endOfLineCommentString)
                _ = OptionParser.parseFrom(line: specialCharacterString)
            }
        }
    }

}
