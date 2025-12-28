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
import XCTest

final class TextImporterTests: XCTestCase {

    func testNew() {
        var result = TextImporterFactory.new(ledger: nil, transaction: "", balance: "")
        XCTAssertNotNil(result)
        XCTAssertTrue(result is ManuLifeImporter)
        result = TextImporterFactory.new(ledger: nil, transaction: "flatexDEGIRO", balance: "")
        XCTAssertNotNil(result)
        XCTAssertTrue(result is EquatePlusImporter)
    }

    func testImporters() {
        XCTAssertEqual(TextImporterFactory.importers.count, 2)
    }

}
