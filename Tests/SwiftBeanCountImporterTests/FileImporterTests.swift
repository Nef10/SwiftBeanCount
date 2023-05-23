//
//  FileImporterTests.swift
//  SwiftBeanCountImporterTests
//
//  Created by Steffen Kötte on 2020-06-07.
//  Copyright © 2020 Steffen Kötte. All rights reserved.
//

import Foundation
@testable import SwiftBeanCountImporter
import SwiftBeanCountModel
import XCTest

final class FileImporterTests: XCTestCase {

    func testImporters() {
        // currently only csv files are supported
        XCTAssertEqual(FileImporterFactory.importers.count, CSVImporterFactory.importers.count)
    }

    func testNew() {
        // no url
        XCTAssertNil(FileImporterFactory.new(ledger: nil, url: nil))

        // invalid URL
        XCTAssertNil(FileImporterFactory.new(ledger: nil, url: URL(fileURLWithPath: "DOES_NOT_EXIST")))

        // valid URL without matching headers
        let url = temporaryFileURL()
        createFile(at: url, content: "Header, no, matching, anything\n")
        XCTAssertNil(FileImporterFactory.new(ledger: nil, url: url))

        // matching header
        let importers = CSVImporterFactory.importers
        for importer in importers {
            for header in importer.headers {
                let url = temporaryFileURL()
                createFile(at: url, content: "\(header.joined(separator: ", "))\n")
                XCTAssertTrue(type(of: FileImporterFactory.new(ledger: nil, url: url)!) == importer) // swiftlint:disable:this xct_specific_matcher
            }
        }
    }

    func testNoEqualImporterTypes() {
        var types = [String]()
        let importers = FileImporterFactory.importers as! [BaseImporter.Type] // swiftlint:disable:this force_cast
        for importer in importers {
            guard !types.contains(importer.importerType) else {
                XCTFail("Importers cannot use the same type")
                return
            }
            types.append(importer.importerType)
        }
    }

}
