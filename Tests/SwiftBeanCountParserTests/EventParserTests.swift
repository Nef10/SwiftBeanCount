//
//  EventParserTests.swift
//  SwiftBeanCountParserTests
//
//  Created by Steffen Kötte on 2019-11-15.
//  Copyright © 2019 Steffen Kötte. All rights reserved.
//


import Foundation
@testable import SwiftBeanCountParser
import SwiftBeanCountModel
import Testing

@Suite

struct EventParserTests {

    private let basicString = "2017-06-09 event \"ABC\" \"DEF\""
    private let whitespaceString = "2017-06-09 event    \"  A B C  \"       \"  D E F  \"     "
    private let endOfLineCommentString = "2017-06-09 event \"ABC\" \"DEF\";gfsdt     "
    private let specialCharacterString = "2017-06-09 event \"ABC💵\" \"DEF💵\""
    private let invalidDateString = "2017-02-30 event \"ABC\" \"DEF\""

   @Test
   func testBasic() {
        let event = EventParser.parseFrom(line: basicString)!
        #expect(event.date == TestUtils.date20170609)
        #expect(event.name == "ABC")
        #expect(event.value == "DEF")
    }

   @Test
   func testWhitespace() {
        let event = EventParser.parseFrom(line: whitespaceString)!
        #expect(event.date == TestUtils.date20170609)
        #expect(event.name == "  A B C  ")
        #expect(event.value == "  D E F  ")
    }

   @Test
   func testEndOfLineComment() {
        let event = EventParser.parseFrom(line: endOfLineCommentString)!
        #expect(event.date == TestUtils.date20170609)
        #expect(event.name == "ABC")
        #expect(event.value == "DEF")
    }

   @Test
   func testSpecialCharacter() {
        let event = EventParser.parseFrom(line: specialCharacterString)!
        #expect(event.date == TestUtils.date20170609)
        #expect(event.name == "ABC💵")
        #expect(event.value == "DEF💵")
    }

   @Test
   func testInvalidDate() {
        #expect(EventParser.parseFrom(line: invalidDateString == nil))
    }

   @Test
   func testPerformance() {
        self.measure {
            for _ in 0...1_000 {
                _ = EventParser.parseFrom(line: basicString)
                _ = EventParser.parseFrom(line: whitespaceString)
                _ = EventParser.parseFrom(line: endOfLineCommentString)
                _ = EventParser.parseFrom(line: specialCharacterString)
            }
        }
    }

}
