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
        XCTAssertEqual(FileImporterManager.importers.count, CSVImporterManager.importers.count)
    }

    func testNew() {
        // no url
        XCTAssertNil(FileImporterManager.new(ledger: nil, url: nil))
    }

}
