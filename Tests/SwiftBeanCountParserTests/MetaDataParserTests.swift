//
//  MetaDataParserTests.swift
//  SwiftBeanCountParserTests
//
//  Created by Steffen Kötte on 2020-05-19.
//  Copyright © 2020 Steffen Kötte. All rights reserved.
//

import Foundation
@testable import SwiftBeanCountParser
import Testing

@Suite

struct MetaDataParserTests {

    private let basicString = "  test:\"ABC\""
    private let whitespaceString = "  test:    \"A B C\"        "
    private let whitespaceBeginningString = "    test:    \"  A B C  \"        "
    private let whitespaceNonMatchingString = " test:\"ABC\""
    private let endOfLineCommentString = "  test: \"ABC\";gfsdt     "
    private let specialCharacterString = "  test💵: \"ABC💵\""

    func testBasic() {
        let metaData = MetaDataParser.parseFrom(line: basicString)
        #expect(metaData == ["test": "ABC"])
    }

    func testWhitespace() {
        let metaData1 = MetaDataParser.parseFrom(line: whitespaceString)
        #expect(metaData1 == ["test": "A B C"])
        let metaData2 = MetaDataParser.parseFrom(line: whitespaceBeginningString)
        #expect(metaData2 == ["test": "  A B C  "])
        let metaData3 = MetaDataParser.parseFrom(line: whitespaceNonMatchingString)
        #expect(metaData3 == nil)
    }

    func testEndOfLineComment() {
        let metaData = MetaDataParser.parseFrom(line: endOfLineCommentString)
        #expect(metaData == ["test": "ABC"])
    }

    func testSpecialCharacter() {
        let metaData = MetaDataParser.parseFrom(line: specialCharacterString)
        #expect(metaData == ["test💵": "ABC💵"])
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
