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
import Testing

class DownloaderTestCase { // swiftlint:disable:this final_test_case

    var mockCredentialStorage: MockCredentialStorage! // swiftlint:disable:this test_case_accessibility

    init() {
        mockCredentialStorage = MockCredentialStorage()
        MockURLProtocol.setup()
    }

    deinit {
        MockURLProtocol.reset()
    }

}
