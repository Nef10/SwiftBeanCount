//
//  PluginParserTests.swift
//  SwiftBeanCountParserTests
//
//  Created by Steffen Kötte on 2019-11-11.
//  Copyright © 2019 Steffen Kötte. All rights reserved.
//

import Foundation
import SwiftBeanCountModel
@testable import SwiftBeanCountParser
import Testing

@Suite
struct PluginParserTests {

    private let basicString = "plugin \"ABC\""
    private let whitespaceString = "plugin    \"  A B C  \"        "
    private let endOfLineCommentString = "plugin \"ABC\";gfsdt     "
    private let specialCharacterString = "plugin \"ABC💵\""

    @Test
    func basic() {
        let plugin = PluginParser.parseFrom(line: basicString)
        #expect(plugin == "ABC")
    }

    @Test
    func whitespace() {
        let plugin = PluginParser.parseFrom(line: whitespaceString)
        #expect(plugin == "  A B C  ")
    }

    @Test
    func endOfLineComment() {
        let plugin = PluginParser.parseFrom(line: endOfLineCommentString)
        #expect(plugin == "ABC")
    }

    @Test
    func specialCharacter() {
        let plugin = PluginParser.parseFrom(line: specialCharacterString)
        #expect(plugin == "ABC💵")
    }

}
