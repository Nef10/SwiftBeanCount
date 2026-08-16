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
import Testing
@testable import WealthsimpleDownloader

class DownloaderTestCase {
    let mockCredentialStorage = MockCredentialStorage()
    let mockHTTPClient = MockHTTPClient()
    let dependencies: DownloaderDependencies

    init() {
        let configuration = URLConfiguration(
            baseURL: "http://localhost:8080/v1/",
            graphQLURL: "http://localhost:8080/graphql"
        )
        dependencies = DownloaderDependencies(httpClient: mockHTTPClient, configuration: configuration)
    }
}
