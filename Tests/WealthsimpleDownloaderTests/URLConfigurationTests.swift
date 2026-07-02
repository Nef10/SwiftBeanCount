//
//  URLConfigurationTests.swift
//
//
// Created by Steffen Kötte on 2025-08-31.
//

import Foundation
import Testing
@testable import WealthsimpleDownloader

@Suite
final class URLConfigurationTests {

    init() {
        // Reset to default base URL before each test
        URLConfiguration.shared.setBaseURL("https://api.production.wealthsimple.com/v1/")
        URLConfiguration.shared.setGraphQLURL("https://my.wealthsimple.com/graphql")
    }

    @Test
    func testDefaultBaseURL() {
        let config = URLConfiguration.shared
        XCTAssertEqual(config.base, "https://api.production.wealthsimple.com/v1/")
        XCTAssertEqual(config.graphQL, "https://my.wealthsimple.com/graphql")
    }

    @Test
    func testSetBaseURL() {
        let config = URLConfiguration.shared
        let testURL = "https://test.example.com/api/v2/"

        config.setBaseURL(testURL)

        XCTAssertEqual(config.base, testURL)
    }

    @Test
    func testSetGraphQLURL() {
        let config = URLConfiguration.shared
        let testURL = "https://test.example.com/graphql"

        config.setGraphQLURL(testURL)

        XCTAssertEqual(config.graphQL, testURL)
    }

    @Test
    func testURLForPath() {
        let config = URLConfiguration.shared
        let result = config.url(for: "accounts")

        XCTAssertEqual(result, "https://api.production.wealthsimple.com/v1/accounts")
    }

    @Test
    func testURLForPathWithCustomBase() {
        let config = URLConfiguration.shared
        config.setBaseURL("https://test.example.com/api/v2/")

        let result = config.url(for: "positions")

        XCTAssertEqual(result, "https://test.example.com/api/v2/positions")
    }

    @Test
    func testURLObjectForPath() {
        let config = URLConfiguration.shared
        let result = config.urlObject(for: "transactions")

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.absoluteString, "https://api.production.wealthsimple.com/v1/transactions")
    }

    @Test
    func testURLComponentsForPath() {
        let config = URLConfiguration.shared
        let result = config.urlComponents(for: "oauth/v2/token")

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.string, "https://api.production.wealthsimple.com/v1/oauth/v2/token")
    }

    @Test
    func testSingletonPattern() {
        let config1 = URLConfiguration.shared
        let config2 = URLConfiguration.shared

        XCTAssertIdentical(config1, config2)
    }

    @Test
    func testConfigurationPersistsBetweenAccesses() {
        let config = URLConfiguration.shared
        let testURL = "https://mock.server.test/v1/"

        config.setBaseURL(testURL)

        // Access through different references
        let newConfig = URLConfiguration.shared
        XCTAssertEqual(newConfig.base, testURL)
    }

    @Test
    func testResetBaseURL() {
        let config = URLConfiguration.shared
        let testURL = "https://mock.server.test/v1/"
        let testGraphQLURL = "https://mock.server.test/graphql"

        config.setBaseURL(testURL)
        XCTAssertEqual(config.base, testURL)

        config.setGraphQLURL(testGraphQLURL)
        XCTAssertEqual(config.graphQL, testGraphQLURL)

        config.reset()
        XCTAssertEqual(config.base, "https://api.production.wealthsimple.com/v1/")
        XCTAssertEqual(config.graphQL, "https://my.wealthsimple.com/graphql")
    }

    @Test
    func testGraphQLURLRequest() {
        let config = URLConfiguration.shared
        let testGraphQLURL = "https://mock.server.test/graphql"
        config.setGraphQLURL(testGraphQLURL)

        guard let request = config.graphQLURLRequest() else {
            XCTFail("Expected valid URLRequest")
            return
        }

        XCTAssertEqual(request.url?.absoluteString, testGraphQLURL)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.allHTTPHeaderFields?["Content-Type"], "application/json")
    }

    @Test
    func testInvalidGraphQLURLRequest() {
        let config = URLConfiguration.shared
        let testGraphQLURL = "Not a valid URL::::////"
        config.setGraphQLURL(testGraphQLURL)

        XCTAssertNil(config.graphQLURLRequest())
    }

}
