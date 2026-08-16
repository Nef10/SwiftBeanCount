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
    @Test
    func defaultBaseURL() {
        let config = URLConfiguration()
        #expect(config.base == "https://api.production.wealthsimple.com/v1/")
        #expect(config.graphQL == "https://my.wealthsimple.com/graphql")
    }

    @Test
    func customBaseURL() {
        let testURL = "https://test.example.com/api/v2/"
        let config = URLConfiguration(baseURL: testURL)
        #expect(config.base == testURL)
    }

    @Test
    func customGraphQLURL() {
        let testURL = "https://test.example.com/graphql"
        let config = URLConfiguration(graphQLURL: testURL)
        #expect(config.graphQL == testURL)
    }

    @Test
    func bothURLsCustom() {
        let testURL = "https://mock.server.test/v1/"
        let testGraphQLURL = "https://mock.server.test/graphql"
        let config = URLConfiguration(baseURL: testURL, graphQLURL: testGraphQLURL)
        #expect(config.base == testURL)
        #expect(config.graphQL == testGraphQLURL)
    }

    @Test
    func uRLForPath() {
        let config = URLConfiguration()
        let result = config.url(for: "accounts")
        #expect(result == "https://api.production.wealthsimple.com/v1/accounts")
    }

    @Test
    func uRLForPathWithCustomBase() {
        let config = URLConfiguration(baseURL: "https://test.example.com/api/v2/")
        let result = config.url(for: "positions")
        #expect(result == "https://test.example.com/api/v2/positions")
    }

    @Test
    func uRLObjectForPath() {
        let config = URLConfiguration()
        let result = config.urlObject(for: "transactions")
        #expect(result != nil)
        #expect(result?.absoluteString == "https://api.production.wealthsimple.com/v1/transactions")
    }

    @Test
    func uRLComponentsForPath() {
        let config = URLConfiguration()
        let result = config.urlComponents(for: "oauth/v2/token")
        #expect(result != nil)
        #expect(result?.string == "https://api.production.wealthsimple.com/v1/oauth/v2/token")
    }

    @Test
    func configurationsAreIndependent() {
        let config1 = URLConfiguration(baseURL: "https://mock.server.test/v1/")
        let config2 = URLConfiguration()
        #expect(config1 !== config2)
        #expect(config1.base == "https://mock.server.test/v1/")
        #expect(config2.base == "https://api.production.wealthsimple.com/v1/")
    }

    @Test
    func graphQLURLRequest() {
        let testGraphQLURL = "https://mock.server.test/graphql"
        let config = URLConfiguration(graphQLURL: testGraphQLURL)
        guard let request = config.graphQLURLRequest() else {
            Issue.record("Expected valid URLRequest")
            return
        }
        #expect(request.url?.absoluteString == testGraphQLURL)
        #expect(request.httpMethod == "POST")
        #expect(request.allHTTPHeaderFields?["Content-Type"] == "application/json")
    }

    @Test
    func invalidGraphQLURLRequest() {
        let testGraphQLURL = "Not a valid URL::::////"
        let config = URLConfiguration(graphQLURL: testGraphQLURL)
        #expect(config.graphQLURLRequest() == nil)
    }
}
