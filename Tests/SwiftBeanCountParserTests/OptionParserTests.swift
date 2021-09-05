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

    private let basicString = "option \"ABC\" \"DEF\""
    private let whitespaceString = "option    \"  A B C  \"       \"  D E F  \"     "
    private let endOfLineCommentString = "option \"ABC\" \"DEF\";gfsdt     "
    private let specialCharacterString = "option \"ABC💵\" \"DEF💵\""

    func testBasic() {
        let option = OptionParser.parseFrom(line: basicString)!
        XCTAssertEqual(option.name, "ABC")
        XCTAssertEqual(option.value, "DEF")
    }

    func testWhitespace() {
        let option = OptionParser.parseFrom(line: whitespaceString)!
        XCTAssertEqual(option.name, "  A B C  ")
        XCTAssertEqual(option.value, "  D E F  ")
    }

    func testEndOfLineComment() {
        let option = OptionParser.parseFrom(line: endOfLineCommentString)!
        XCTAssertEqual(option.name, "ABC")
        XCTAssertEqual(option.value, "DEF")
    }

    func testSpecialCharacter() {
        let option = OptionParser.parseFrom(line: specialCharacterString)!
        XCTAssertEqual(option.name, "ABC💵")
        XCTAssertEqual(option.value, "DEF💵")
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
