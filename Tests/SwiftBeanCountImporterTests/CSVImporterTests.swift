//
//  CSVImporterTests.swift
//  SwiftBeanCountImporterTests
//
//  Created by Steffen Kötte on 2020-06-06.
//  Copyright © 2020 Steffen Kötte. All rights reserved.
//

import Foundation
@testable import SwiftBeanCountImporter
import SwiftBeanCountModel
import XCTest

final class CSVImporterTests: XCTestCase {

    func testImporters() {
        XCTAssertEqual(CSVImporterManager.importers.count, 7)
    }

    func testNew() {
        // no url
        XCTAssertNil(CSVImporterManager.new(ledger: nil, url: nil))

        // invalid URL
        XCTAssertNil(CSVImporterManager.new(ledger: nil, url: URL(fileURLWithPath: "DOES_NOT_EXIST")))

        // valid URL without matching headers
        let url = temporaryFileURL()
        createFile(at: url, content: "Header, no, matching, anything\n")
        XCTAssertNil(CSVImporterManager.new(ledger: nil, url: url))

        // matching header
        let importers = CSVImporterManager.importers
        for importer in importers {
            let url = temporaryFileURL()
            createFile(at: url, content: "\(importer.header.joined(separator: ", "))\n")
            XCTAssertTrue(type(of: CSVImporterManager.new(ledger: nil, url: url)!) == importer)
        }
    }

}
