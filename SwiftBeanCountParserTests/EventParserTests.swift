//
//  EventParserTests.swift
//  SwiftBeanCountParserTests
//
//  Created by Steffen Kötte on 2019-11-15.
//  Copyright © 2019 Steffen Kötte. All rights reserved.
//

import SwiftBeanCountModel
@testable import SwiftBeanCountParser
import XCTest

class EventParserTests: XCTestCase {

    let basicString = "2017-06-09 event \"ABC\" \"DEF\""
    let whitespaceString = "2017-06-09 event    \"ABC\"       \"DEF\"     "
    let endOfLineCommentString = "2017-06-09 event \"ABC\" \"DEF\";gfsdt     "
    let specialCharacterString = "2017-06-09 event \"ABC💵\" \"DEF💵\""
    let invalidDateString = "2017-02-30 event \"ABC\" \"DEF\""

    func testBasic() {
        let event = EventParser.parseFrom(line: basicString)!
        XCTAssertEqual(event.date, TestUtils.date20170609)
        XCTAssertEqual(event.name, "ABC")
        XCTAssertEqual(event.value, "DEF")
    }

    func testWhitespace() {
        let event = EventParser.parseFrom(line: whitespaceString)!
        XCTAssertEqual(event.date, TestUtils.date20170609)
        XCTAssertEqual(event.name, "ABC")
        XCTAssertEqual(event.value, "DEF")
    }

    func testEndOfLineComment() {
        let event = EventParser.parseFrom(line: endOfLineCommentString)!
        XCTAssertEqual(event.date, TestUtils.date20170609)
        XCTAssertEqual(event.name, "ABC")
        XCTAssertEqual(event.value, "DEF")
    }

    func testSpecialCharacter() {
        let event = EventParser.parseFrom(line: specialCharacterString)!
        XCTAssertEqual(event.date, TestUtils.date20170609)
        XCTAssertEqual(event.name, "ABC💵")
        XCTAssertEqual(event.value, "DEF💵")
    }

    func testInvalidDate() {
        XCTAssertNil(EventParser.parseFrom(line: invalidDateString))
    }

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
