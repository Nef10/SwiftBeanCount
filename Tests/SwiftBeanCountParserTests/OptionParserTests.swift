//
//  OptionParserTests.swift
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
struct OptionParserTests {

    private let basicString = "option \"ABC\" \"DEF\""
    private let whitespaceString = "option    \"  A B C  \"       \"  D E F  \"     "
    private let endOfLineCommentString = "option \"ABC\" \"DEF\";gfsdt     "
    private let specialCharacterString = "option \"ABC💵\" \"DEF💵\""

    @Test
    func basic() {
        let option = OptionParser.parseFrom(line: basicString)!
        #expect(option.name == "ABC")
        #expect(option.value == "DEF")
    }

    @Test
    func whitespace() {
        let option = OptionParser.parseFrom(line: whitespaceString)!
        #expect(option.name == "  A B C  ")
        #expect(option.value == "  D E F  ")
    }

    @Test
    func endOfLineComment() {
        let option = OptionParser.parseFrom(line: endOfLineCommentString)!
        #expect(option.name == "ABC")
        #expect(option.value == "DEF")
    }

    @Test
    func specialCharacter() {
        let option = OptionParser.parseFrom(line: specialCharacterString)!
        #expect(option.name == "ABC💵")
        #expect(option.value == "DEF💵")
    }

}
