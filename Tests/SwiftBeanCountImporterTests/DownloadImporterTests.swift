//
//  DownloadImporterTests.swift
//  SwiftBeanCountImporterTests
//
//  Created by Steffen Kötte on 2021-09-14.
//  Copyright © 2021 Steffen Kötte. All rights reserved.
//

import Foundation
@testable import SwiftBeanCountImporter
import SwiftBeanCountModel
import XCTest

final class DownloadImporterTests: XCTestCase {

    func testImporters() {
        XCTAssertEqual(DownloadImporterFactory.importers.count, 1)
    }

    func testNew() {
        XCTAssertNil(DownloadImporterFactory.new(ledger: Ledger(), name: "This is not a valid name"))

        let importers = DownloadImporterFactory.importers
        for importer in importers {
            XCTAssertTrue(type(of: DownloadImporterFactory.new(ledger: nil, name: importer.importerName)!) == importer)
        }
    }

    func testNoEqualName() {
        var names = [String]()
        let importers = DownloadImporterFactory.importers
        for importer in importers {
            guard !names.contains(importer.importerName) else {
                XCTFail("Importers cannot use the same name")
                return
            }
            names.append(importer.importerName)
        }
    }

}
