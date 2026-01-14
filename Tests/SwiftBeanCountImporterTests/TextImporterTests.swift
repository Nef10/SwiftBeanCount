//
//  TextImporterTests.swift
//  SwiftBeanCountImporterTests
//
//  Created by Steffen Kötte on 2020-06-06.
//  Copyright © 2020 Steffen Kötte. All rights reserved.
//

import Foundation
@testable import SwiftBeanCountImporter
import SwiftBeanCountModel
import Testing

@Suite
struct TextImporterTests {

    @Test
    func new() {
        var result = TextImporterFactory.new(ledger: nil, transaction: "", balance: "")
        #expect(result != nil)
        #expect(result is ManuLifeImporter)
        result = TextImporterFactory.new(ledger: nil, transaction: "flatexDEGIRO", balance: "")
        #expect(result != nil)
        #expect(result is EquatePlusImporter)
    }

    @Test
    func importers() {
        #expect(TextImporterFactory.importers.count == 2)
    }

}
