//
//  TagTests.swift
//  SwiftBeanCountModelTests
//
//  Created by Steffen Kötte on 2017-06-14.
//  Copyright © 2017 Steffen Kötte. All rights reserved.
//

import Foundation
@testable import SwiftBeanCountModel
import Testing

@Suite

struct TagTests {

    func testDescription() {
        let string = "String"
        let tag = Tag(name: string)
        #expect(String(describing: tag) == "#" + string)
    }

    func testDescriptionSpecialCharacters() {
        let string = "#️⃣"
        let tag = Tag(name: string)
        #expect(String(describing: tag) == "#" + string)
    }

    func testEqual() {
        let string1 = "String1"
        let string2 = "String2"
        let tag1 = Tag(name: string1)
        let tag2 = Tag(name: string1)
        let tag3 = Tag(name: string2)

        #expect(tag1 == tag2)
        #expect(tag1 == tag2) // swiftlint:disable:this xct_specific_matcher

        #expect(tag1 != tag3)
        #expect(tag1 != tag3) // swiftlint:disable:this xct_specific_matcher

        #expect(tag2 != tag3)
        #expect(tag2 != tag3) // swiftlint:disable:this xct_specific_matcher
    }

    func testGreater() {
        let string1 = "A"
        let string2 = "B"
        let tag1 = Tag(name: string1)
        let tag2 = Tag(name: string2)

        #expect(tag1 < tag2)
        #expect(!(tag1 > tag2))

        #expect(!(tag1 > tag1)) // swiftlint:disable:this identical_operands
        #expect(!(tag2 < tag2)) // swiftlint:disable:this identical_operands
    }

}
