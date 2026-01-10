//
//  CustomsParserTests.swift
//  SwiftBeanCountParserTests
//
//  Created by Koette, Steffen on 2019-11-20.
//  Copyright © 2019 Steffen Kötte. All rights reserved.
//

import Foundation
import SwiftBeanCountModel
@testable import SwiftBeanCountParser
import Testing

@Suite

struct CustomsParserTests {

    private let basicString = "2017-06-09 custom \"ABC\" \"DEF\""
    private let multipleValuesString = "2017-06-09 custom \"ABC\" \"DEF\" \"GHI\" \"JKL\" \"MNO\""
    private let whitespaceString = "2017-06-09 custom    \"  A B C  \"       \"  D E F  \"      \"G H I\"       "
    private let endOfLineCommentString = "2017-06-09 custom \"ABC\" \"DEF\"  \"GHI\";gfsdt     "
    private let specialCharacterString = "2017-06-09 custom \"ABC💵\" \"DEF💵\" \"GHI💵\""
    private let invalidDateString = "2017-02-30 custom \"ABC\" \"DEF\""

   @Test
   func testBasic() {
        let event = CustomsParser.parseFrom(line: basicString)!
        #expect(event.date == TestUtils.date20170609)
        #expect(event.name == "ABC")
        #expect(event.values == ["DEF"])
    }

   @Test
   func testMultipleValues() {
        let event = CustomsParser.parseFrom(line: multipleValuesString)!
        #expect(event.date == TestUtils.date20170609)
        #expect(event.name == "ABC")
        #expect(event.values == ["DEF", "GHI", "JKL", "MNO"])
    }

   @Test
   func testWhitespace() {
        let event = CustomsParser.parseFrom(line: whitespaceString)!
        #expect(event.date == TestUtils.date20170609)
        #expect(event.name == "  A B C  ")
        #expect(event.values == ["  D E F  ", "G H I"])
    }

   @Test
   func testEndOfLineComment() {
        let event = CustomsParser.parseFrom(line: endOfLineCommentString)!
        #expect(event.date == TestUtils.date20170609)
        #expect(event.name == "ABC")
        #expect(event.values == ["DEF", "GHI"])
    }

   @Test
   func testSpecialCharacter() {
        let event = CustomsParser.parseFrom(line: specialCharacterString)!
        #expect(event.date == TestUtils.date20170609)
        #expect(event.name == "ABC💵")
        #expect(event.values == ["DEF💵", "GHI💵"])
    }

   @Test
   func testInvalidDate() {
        #expect(CustomsParser.parseFrom(line: invalidDateString == nil))
    }

   @Test
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
