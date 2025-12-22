//
//  OptionTests.swift
//  SwiftBeanCountModelTests
//
//  Created by Steffen Kötte on 2020-05-18.
//  Copyright © 2020 Steffen Kötte. All rights reserved.
//

@testable import SwiftBeanCountModel
import XCTest

final class OptionTests: XCTestCase {

    func testDescription() {
        let option = Option(name: "name", value: "value1")
        XCTAssertEqual(String(describing: option), "option \"name\" \"value1\"")

        let optionSpecialCharacters = Option(name: "😂", value: "😀")
        XCTAssertEqual(String(describing: optionSpecialCharacters), "option \"😂\" \"😀\"")
    }

    func testComparable() {
        let option1 = Option(name: "name", value: "value1")
        let option2 = Option(name: "name", value: "value1")
        let option3 = Option(name: "name1", value: "value1") // check name
        let option4 = Option(name: "name", value: "value2") // check value
        XCTAssertEqual(option1, option2)
        XCTAssertNotEqual(option1, option3)
        XCTAssertNotEqual(option1, option4)
    }

}
