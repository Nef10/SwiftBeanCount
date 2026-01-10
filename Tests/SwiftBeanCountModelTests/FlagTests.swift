//
//  FlagTests.swift
//  SwiftBeanCountModelTests
//
//  Created by Steffen Kötte on 2017-06-18.
//  Copyright © 2017 Steffen Kötte. All rights reserved.
//


import Foundation
@testable import SwiftBeanCountModel
import Testing

@Suite

struct FlagTests {

   @Test
   func testDescription() {
        let complete = Flag.complete
        #expect(String(describing: complete) == "*")
        let incomplete = Flag.incomplete
        #expect(String(describing: incomplete) == "!")
    }

}
