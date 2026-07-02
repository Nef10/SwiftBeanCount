//
//  URLConfigurationTests.swift
//
//
// Created by Steffen Kötte on 2025-08-31.
//

import Foundation
import Testing
@testable import WealthsimpleDownloader

@Suite(.serialized)
final class URLConfigurationTests {

    init() {
        // Reset to default base URL before each test
        URLConfiguration.shared.setBaseURL("https://api.production.wealthsimple.com/v1/")
        URLConfiguration.shared.setGraphQLURL("https://my.wealthsimple.com/graphql")
    }

    @Test
    func testDefaultBaseURL() {
        let config = URLConfiguration.shared
        expectEqual(config.base, "https://api.production.wealthsimple.com/v1/")
        expectEqual(config.graphQL, "https://my.wealthsimple.com/graphql")
    }

    @Test
    func testSetBaseURL() {
        let config = URLConfiguration.shared
        let testURL = "https://test.example.com/api/v2/"

        config.setBaseURL(testURL)

        expectEqual(config.base, testURL)
    }

    @Test
    func testSetGraphQLURL() {
        let config = URLConfiguration.shared
        let testURL = "https://test.example.com/graphql"

        config.setGraphQLURL(testURL)

        expectEqual(config.graphQL, testURL)
    }

    @Test
    func testURLForPath() {
        let config = URLConfiguration.shared
        let result = config.url(for: "accounts")

        expectEqual(result, "https://api.production.wealthsimple.com/v1/accounts")
    }

    @Test
    func testURLForPathWithCustomBase() {
        let config = URLConfiguration.shared
        config.setBaseURL("https://test.example.com/api/v2/")

        let result = config.url(for: "positions")

        expectEqual(result, "https://test.example.com/api/v2/positions")
    }

    @Test
    func testURLObjectForPath() {
        let config = URLConfiguration.shared
        let result = config.urlObject(for: "transactions")

        expectNotNil(result)
        expectEqual(result?.absoluteString, "https://api.production.wealthsimple.com/v1/transactions")
    }

    @Test
    func testURLComponentsForPath() {
        let config = URLConfiguration.shared
        let result = config.urlComponents(for: "oauth/v2/token")

        expectNotNil(result)
        expectEqual(result?.string, "https://api.production.wealthsimple.com/v1/oauth/v2/token")
    }

    @Test
    func testSingletonPattern() {
        let config1 = URLConfiguration.shared
        let config2 = URLConfiguration.shared

        expectIdentical(config1, config2)
    }

    @Test
    func testConfigurationPersistsBetweenAccesses() {
        let config = URLConfiguration.shared
        let testURL = "https://mock.server.test/v1/"

        config.setBaseURL(testURL)

        // Access through different references
        let newConfig = URLConfiguration.shared
        expectEqual(newConfig.base, testURL)
    }

    @Test
    func testResetBaseURL() {
        let config = URLConfiguration.shared
        let testURL = "https://mock.server.test/v1/"
        let testGraphQLURL = "https://mock.server.test/graphql"

        config.setBaseURL(testURL)
        expectEqual(config.base, testURL)

        config.setGraphQLURL(testGraphQLURL)
        expectEqual(config.graphQL, testGraphQLURL)

        config.reset()
        expectEqual(config.base, "https://api.production.wealthsimple.com/v1/")
        expectEqual(config.graphQL, "https://my.wealthsimple.com/graphql")
    }

    @Test
    func testGraphQLURLRequest() {
        let config = URLConfiguration.shared
        let testGraphQLURL = "https://mock.server.test/graphql"
        config.setGraphQLURL(testGraphQLURL)

        guard let request = config.graphQLURLRequest() else {
            recordFailure("Expected valid URLRequest")
            return
        }

        expectEqual(request.url?.absoluteString, testGraphQLURL)
        expectEqual(request.httpMethod, "POST")
        expectEqual(request.allHTTPHeaderFields?["Content-Type"], "application/json")
    }

    @Test
    func testInvalidGraphQLURLRequest() {
        let config = URLConfiguration.shared
        let testGraphQLURL = "Not a valid URL::::////"
        config.setGraphQLURL(testGraphQLURL)

        expectNil(config.graphQLURLRequest())
    }

}
