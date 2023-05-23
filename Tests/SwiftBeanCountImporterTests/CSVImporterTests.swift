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
        XCTAssertEqual(CSVImporterFactory.importers.count, 8)
    }

    func testNew() {
        // no url
        XCTAssertNil(CSVImporterFactory.new(ledger: nil, url: nil))

        // invalid URL
        XCTAssertNil(CSVImporterFactory.new(ledger: nil, url: URL(fileURLWithPath: "DOES_NOT_EXIST")))

        // valid URL without matching headers
        let url = temporaryFileURL()
        createFile(at: url, content: "Header, no, matching, anything\n")
        XCTAssertNil(CSVImporterFactory.new(ledger: nil, url: url))

        // matching header
        let importers = CSVImporterFactory.importers
        for importer in importers {
            for header in importer.headers {
                let url = temporaryFileURL()
                createFile(at: url, content: "\(header.joined(separator: ", "))\n")
                XCTAssertTrue(type(of: CSVImporterFactory.new(ledger: nil, url: url)!) == importer) // swiftlint:disable:this xct_specific_matcher
            }
        }
    }

    func testNoEqualHeaders() {
        var headers = [[String]]()
        let importers = CSVImporterFactory.importers
        for importer in importers {
            for header in importer.headers {
                guard !headers.contains(header) else {
                    XCTFail("Importers cannot use the same headers")
                    return
                }
                headers.append(header)
            }
        }
    }

}
