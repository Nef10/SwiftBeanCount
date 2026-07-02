//
//  DownloaderTestCase.swift
//
//
//  Created by Steffen Kötte on 2025-09-03.
//

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import WealthsimpleDownloader
import XCTest

class DownloaderTestCase: XCTestCase { // swiftlint:disable:this final_test_case

    var mockCredentialStorage: MockCredentialStorage! // swiftlint:disable:this test_case_accessibility

    override func setUp() {
        super.setUp()
        mockCredentialStorage = MockCredentialStorage()
        MockURLProtocol.setup()
    }

    override func tearDown() {
        MockURLProtocol.reset()
        super.tearDown()
    }

}
