//
//  DateParserTests.swift
//  SwiftBeanCountParserTests
//
//  Created by Steffen Kötte on 2017-06-17.
//  Copyright © 2017 Steffen Kötte. All rights reserved.
//

import Foundation
@testable import SwiftBeanCountParser
import Testing

@Suite
struct DateParserTests {

    @Test
    func normalParsing() {
        let date = DateParser.parseFrom(string: "2017-06-09")
        #expect(date == TestUtils.date20170609)
    }

    @Test
    func invalidDate() {
        let date = DateParser.parseFrom(string: "2017-00-09")
        #expect(date == nil)
    }

    @Test
    func nonExistentDate() {
        let date = DateParser.parseFrom(string: "2017-02-30")
        #expect(date == nil)
    }

}
