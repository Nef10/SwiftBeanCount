//
//  CollectionTests.swift
//  SwiftBeanCountParserTests
//
//  Created by Steffen Kötte on 2017-06-10.
//  Copyright © 2017 Steffen Kötte. All rights reserved.
//

import Foundation
@testable import SwiftBeanCountParser
import Testing

@Suite

struct CollectionTests {

    func testSafeArray() {
        var array = [String]()
        #expect(array[safe: 0] == nil)
        array.append("value")
        #expect(array[safe: 0] == "value")
        #expect(array[safe: 1] == nil)
    }

}
