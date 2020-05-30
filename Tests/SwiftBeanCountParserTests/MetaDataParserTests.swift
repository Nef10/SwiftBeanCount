//
//  MetaDataParserTests.swift
//  SwiftBeanCountParserTests
//
//  Created by Steffen Kötte on 2020-05-19.
//  Copyright © 2020 Steffen Kötte. All rights reserved.
//

@testable import SwiftBeanCountParser
import XCTest

class MetaDataParserTests: XCTestCase {

    let basicString = "  test:\"ABC\""
    let whitespaceString = "  test:    \"A B C\"        "
    let whitespaceBeginningString = "    test:    \"  A B C  \"        "
    let whitespaceNonMatchingString = " test:\"ABC\""
    let endOfLineCommentString = "  test: \"ABC\";gfsdt     "
    let specialCharacterString = "  test💵: \"ABC💵\""

    func testBasic() {
        let metaData = MetaDataParser.parseFrom(line: basicString)
        XCTAssertEqual(metaData, ["test": "ABC"])
    }

    func testWhitespace() {
        let metaData1 = MetaDataParser.parseFrom(line: whitespaceString)
        XCTAssertEqual(metaData1, ["test": "A B C"])
        let metaData2 = MetaDataParser.parseFrom(line: whitespaceBeginningString)
        XCTAssertEqual(metaData2, ["test": "  A B C  "])
        let metaData3 = MetaDataParser.parseFrom(line: whitespaceNonMatchingString)
        XCTAssertNil(metaData3)
    }

    func testEndOfLineComment() {
        let metaData = MetaDataParser.parseFrom(line: endOfLineCommentString)
        XCTAssertEqual(metaData, ["test": "ABC"])
    }

    func testSpecialCharacter() {
        let metaData = MetaDataParser.parseFrom(line: specialCharacterString)
        XCTAssertEqual(metaData, ["test💵": "ABC💵"])
    }

    func testPerformance() {
        self.measure {
            for _ in 0...1_000 {
                _ = MetaDataParser.parseFrom(line: basicString)
                _ = MetaDataParser.parseFrom(line: whitespaceString)
                _ = MetaDataParser.parseFrom(line: whitespaceBeginningString)
                _ = MetaDataParser.parseFrom(line: endOfLineCommentString)
                _ = MetaDataParser.parseFrom(line: specialCharacterString)
            }
        }
    }

}
