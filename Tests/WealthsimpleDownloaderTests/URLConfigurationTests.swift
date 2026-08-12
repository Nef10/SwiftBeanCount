//
//  URLConfigurationTests.swift
//
//
// Created by Steffen Kötte on 2025-08-31.
//
import Foundation
import Testing
@testable import WealthsimpleDownloader
@Suite(.urlConfigurationSerialized, .serialized)
final class URLConfigurationTests {
   init() {
       // Reset to default base URL before each test
       URLConfiguration.shared.setBaseURL("https://api.production.wealthsimple.com/v1/")
       URLConfiguration.shared.setGraphQLURL("https://my.wealthsimple.com/graphql")
   }
   @Test
   func defaultBaseURL() {
       let config = URLConfiguration.shared
       #expect(config.base == "https://api.production.wealthsimple.com/v1/")
       #expect(config.graphQL == "https://my.wealthsimple.com/graphql")
   }
   @Test
   func setBaseURL() {
       let config = URLConfiguration.shared
       let testURL = "https://test.example.com/api/v2/"
       config.setBaseURL(testURL)
       #expect(config.base == testURL)
   }
   @Test
   func setGraphQLURL() {
       let config = URLConfiguration.shared
       let testURL = "https://test.example.com/graphql"
       config.setGraphQLURL(testURL)
       #expect(config.graphQL == testURL)
   }
   @Test
   func uRLForPath() {
       let config = URLConfiguration.shared
       let result = config.url(for: "accounts")
       #expect(result == "https://api.production.wealthsimple.com/v1/accounts")
   }
   @Test
   func uRLForPathWithCustomBase() {
       let config = URLConfiguration.shared
       config.setBaseURL("https://test.example.com/api/v2/")
       let result = config.url(for: "positions")
       #expect(result == "https://test.example.com/api/v2/positions")
   }
   @Test
   func uRLObjectForPath() {
       let config = URLConfiguration.shared
       let result = config.urlObject(for: "transactions")
       #expect(result != nil)
       #expect(result?.absoluteString == "https://api.production.wealthsimple.com/v1/transactions")
   }
   @Test
   func uRLComponentsForPath() {
       let config = URLConfiguration.shared
       let result = config.urlComponents(for: "oauth/v2/token")
       #expect(result != nil)
       #expect(result?.string == "https://api.production.wealthsimple.com/v1/oauth/v2/token")
   }
   @Test
   func singletonPattern() {
       let config1 = URLConfiguration.shared
       let config2 = URLConfiguration.shared
       #expect(config1 === config2)
   }
   @Test
   func configurationPersistsBetweenAccesses() {
       let config = URLConfiguration.shared
       let testURL = "https://mock.server.test/v1/"
       config.setBaseURL(testURL)
       // Access through different references
       let newConfig = URLConfiguration.shared
       #expect(newConfig.base == testURL)
   }
   @Test
   func resetBaseURL() {
       let config = URLConfiguration.shared
       let testURL = "https://mock.server.test/v1/"
       let testGraphQLURL = "https://mock.server.test/graphql"
       config.setBaseURL(testURL)
       #expect(config.base == testURL)
       config.setGraphQLURL(testGraphQLURL)
       #expect(config.graphQL == testGraphQLURL)
       config.reset()
       #expect(config.base == "https://api.production.wealthsimple.com/v1/")
       #expect(config.graphQL == "https://my.wealthsimple.com/graphql")
   }
   @Test
   func graphQLURLRequest() {
       let config = URLConfiguration.shared
       let testGraphQLURL = "https://mock.server.test/graphql"
       config.setGraphQLURL(testGraphQLURL)
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
       let config = URLConfiguration.shared
       let testGraphQLURL = "Not a valid URL::::////"
       config.setGraphQLURL(testGraphQLURL)
       #expect(config.graphQLURLRequest() == nil)
   }
}
