//
//  OptionParserTests.swift
//  SwiftBeanCountParserTests
//
//  Created by Steffen Kötte on 2019-11-11.
//  Copyright © 2019 Steffen Kötte. All rights reserved.
//

import Foundation
import SwiftBeanCountModel
@testable import SwiftBeanCountParser
import Testing

@Suite

struct OptionParserTests {

    private let basicString = "option \"ABC\" \"DEF\""
    private let whitespaceString = "option    \"  A B C  \"       \"  D E F  \"     "
    private let endOfLineCommentString = "option \"ABC\" \"DEF\";gfsdt     "
    private let specialCharacterString = "option \"ABC💵\" \"DEF💵\""

   @Test
   func testBasic() {
        let option = OptionParser.parseFrom(line: basicString)!
        #expect(option.name == "ABC")
        #expect(option.value == "DEF")
    }

   @Test
   func testWhitespace() {
        let option = OptionParser.parseFrom(line: whitespaceString)!
        #expect(option.name == "  A B C  ")
        #expect(option.value == "  D E F  ")
    }

   @Test
   func testEndOfLineComment() {
        let option = OptionParser.parseFrom(line: endOfLineCommentString)!
        #expect(option.name == "ABC")
        #expect(option.value == "DEF")
    }

   @Test
   func testSpecialCharacter() {
        let option = OptionParser.parseFrom(line: specialCharacterString)!
        #expect(option.name == "ABC💵")
        #expect(option.value == "DEF💵")
    }

   @Test
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
