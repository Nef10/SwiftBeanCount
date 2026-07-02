//
//  URLConfiguration.swift
//
//
// Created by Steffen Kötte on 2025-08-31.
//

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Singleton class that manages the base URL configuration for all Wealthsimple API endpoints
final class URLConfiguration {

    private static let defaultBaseURL = "https://api.production.wealthsimple.com/v1/"
    private static let defaultGraphQLURL = "https://my.wealthsimple.com/graphql"

    /// Shared singleton instance
    static let shared = URLConfiguration()

    /// Base URL for all Wealthsimple API endpoints
    private var baseURL: String = URLConfiguration.defaultBaseURL
    /// GraphQL URL for Wealthsimple
    private var graphQLURL: String = URLConfiguration.defaultGraphQLURL

    /// Get the current base URL
    var base: String {
        baseURL
    }

    /// Get the current graphQL URL
    var graphQL: String {
        graphQLURL
    }

    /// Private initializer to enforce singleton pattern
    private init() {
        // Singleton initialization
    }

    /// Set a new base URL (internal access for testing)
    /// - Parameter url: The new base URL to use
    func setBaseURL(_ url: String) {
        baseURL = url
    }

    /// Set a new graphQL URL (internal access for testing)
    /// - Parameter url: The new base URL to use
    func setGraphQLURL(_ url: String) {
        graphQLURL = url
    }

    /// Create a full URL by appending a path to the base URL
    /// - Parameter path: The path to append (should not start with /)
    /// - Returns: The complete URL string
    func url(for path: String) -> String {
        baseURL + path
    }

    /// Create a URL object by appending a path to the base URL
    /// - Parameter path: The path to append (should not start with /)
    /// - Returns: A URL object, or nil if the URL is invalid
    func urlObject(for path: String) -> URL? {
        URL(string: url(for: path))
    }

    /// Create a URLComponents object by appending a path to the base URL
    /// - Parameter path: The path to append (should not start with /)
    /// - Returns: A URLComponents object, or nil if the URL is invalid
    func urlComponents(for path: String) -> URLComponents? {
        URLComponents(string: url(for: path))
    }

    /// Create a URLRequest object for GraphQL URL
    /// - Returns: A URLRequest, or nil if the URL is invalid
    func graphQLURLRequest() -> URLRequest? {
        let url = URL(string: graphQL)
        guard let url else {
            return nil
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return request
    }

    func reset() {
        baseURL = Self.defaultBaseURL
        graphQLURL = Self.defaultGraphQLURL
    }

}
