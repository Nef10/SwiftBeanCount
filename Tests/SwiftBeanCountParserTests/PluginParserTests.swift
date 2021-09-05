//
//  PluginParserTests.swift
//  SwiftBeanCountParserTests
//
//  Created by Steffen Kötte on 2019-11-11.
//  Copyright © 2019 Steffen Kötte. All rights reserved.
//

import SwiftBeanCountModel
@testable import SwiftBeanCountParser
import XCTest

class PluginParserTests: XCTestCase {

    private let basicString = "plugin \"ABC\""
    private let whitespaceString = "plugin    \"  A B C  \"        "
    private let endOfLineCommentString = "plugin \"ABC\";gfsdt     "
    private let specialCharacterString = "plugin \"ABC💵\""

    func testBasic() {
        let plugin = PluginParser.parseFrom(line: basicString)
        XCTAssertEqual(plugin, "ABC")
    }

    func testWhitespace() {
        let plugin = PluginParser.parseFrom(line: whitespaceString)
        XCTAssertEqual(plugin, "  A B C  ")
    }

    func testEndOfLineComment() {
        let plugin = PluginParser.parseFrom(line: endOfLineCommentString)
        XCTAssertEqual(plugin, "ABC")
    }

    func testSpecialCharacter() {
        let plugin = PluginParser.parseFrom(line: specialCharacterString)
        XCTAssertEqual(plugin, "ABC💵")
    }

    func testPerformance() {
        self.measure {
            for _ in 0...1_000 {
                _ = PluginParser.parseFrom(line: basicString)
                _ = PluginParser.parseFrom(line: whitespaceString)
                _ = PluginParser.parseFrom(line: endOfLineCommentString)
                _ = PluginParser.parseFrom(line: specialCharacterString)
            }
        }
    }

}
