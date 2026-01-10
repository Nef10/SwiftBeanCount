//
//  OptionTests.swift
//  SwiftBeanCountModelTests
//
//  Created by Steffen Kötte on 2020-05-18.
//  Copyright © 2020 Steffen Kötte. All rights reserved.
//


import Foundation
@testable import SwiftBeanCountModel
import Testing

@Suite

struct OptionTests {

   @Test
   func testDescription() {
        let option = Option(name: "name", value: "value1")
        #expect(String(describing: option) == "option \"name\" \"value1\"")

        let optionSpecialCharacters = Option(name: "😂", value: "😀")
        #expect(String(describing: optionSpecialCharacters) == "option \"😂\" \"😀\"")
    }

   @Test
   func testComparable() {
        let option1 = Option(name: "name", value: "value1")
        let option2 = Option(name: "name", value: "value1")
        let option3 = Option(name: "name1", value: "value1") // check name
        let option4 = Option(name: "name", value: "value2") // check value
        #expect(option1 == option2)
        #expect(option1 != option3)
        #expect(option1 != option4)
    }

}
