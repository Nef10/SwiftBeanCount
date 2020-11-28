//
//  TagTests.swift
//  SwiftBeanCountModelTests
//
//  Created by Steffen Kötte on 2017-06-14.
//  Copyright © 2017 Steffen Kötte. All rights reserved.
//

@testable import SwiftBeanCountModel
import XCTest

class TagTests: XCTestCase {

    func testDescription() {
        let string = "String"
        let tag = Tag(name: string)
        XCTAssertEqual(String(describing: tag), "#" + string)
    }

    func testDescriptionSpecialCharacters() {
        let string = "#️⃣"
        let tag = Tag(name: string)
        XCTAssertEqual(String(describing: tag), "#" + string)
    }

    func testEqual() {
        let string1 = "String1"
        let string2 = "String2"
        let tag1 = Tag(name: string1)
        let tag2 = Tag(name: string1)
        let tag3 = Tag(name: string2)

        XCTAssert(tag1 == tag2)
        XCTAssertEqual(tag1, tag2)

        XCTAssertNotEqual(tag1, tag3)
        XCTAssert(tag1 != tag3)

        XCTAssertNotEqual(tag2, tag3)
        XCTAssert(tag2 != tag3)
    }

    func testGreater() {
        let string1 = "A"
        let string2 = "B"
        let tag1 = Tag(name: string1)
        let tag2 = Tag(name: string2)

        XCTAssert(tag1 < tag2)
        XCTAssertFalse(tag1 > tag2)

        XCTAssertFalse(tag1 > tag1) // swiftlint:disable:this identical_operands
        XCTAssertFalse(tag2 < tag2) // swiftlint:disable:this identical_operands
    }

}
