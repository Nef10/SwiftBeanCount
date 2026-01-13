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
import Testing

@Suite
struct CSVImporterTests {

    @Test
    func importers() {
        #expect(CSVImporterFactory.importers.count == 8)
    }

    @Test
    func new() {
        // no url
        #expect(CSVImporterFactory.new(ledger: nil, url: nil) == nil)

        // invalid URL
        #expect(CSVImporterFactory.new(ledger: nil, url: URL(fileURLWithPath: "DOES_NOT_EXIST")) == nil)

        // valid URL without matching headers
        let (url, cleanup) = TestUtils.temporaryFileURL()
        TestUtils.createFile(at: url, content: "Header, no, matching, anything\n")
        #expect(CSVImporterFactory.new(ledger: nil, url: url) == nil)
        cleanup()

        // matching header
        let importers = CSVImporterFactory.importers
        for importer in importers {
            for header in importer.headers {
                let (url, cleanup) = TestUtils.temporaryFileURL()
                TestUtils.createFile(at: url, content: "\(header.joined(separator: ", "))\n")
                #expect(type(of: CSVImporterFactory.new(ledger: nil, url: url)!) == importer)
                cleanup()
            }
        }
    }

    @Test
    func noEqualHeaders() {
        var headers = [[String]]()
        let importers = CSVImporterFactory.importers
        for importer in importers {
            for header in importer.headers {
                guard !headers.contains(header) else {
                    Issue.record("Importers cannot use the same headers")
                    return
                }
                headers.append(header)
            }
        }
    }

}
