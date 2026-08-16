//
//  MockHTTPClient.swift
//
//
//  Created by Steffen Kötte on 2025-08-31.
//

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Testing
@testable import WealthsimpleDownloader

/// An instance-scoped HTTP client for downloader tests.
final class MockHTTPClient: HTTPClient {
    var newTokenRequestHandler: ((URL, URLRequest) throws -> (URLResponse, Data)) = failTest
    var tokenValidationRequestHandler: ((URL, URLRequest) throws -> (URLResponse, Data)) = failTest
    var accountsRequestHandler: ((URL, URLRequest) throws -> (URLResponse, Data)) = failTest
    var transactionsRequestHandler: ((URL, URLRequest) throws -> (URLResponse, Data)) = failTest
    var positionsRequestHandler: ((URL, URLRequest) throws -> (URLResponse, Data)) = failTest
    var graphQLRequestHandler: ((URL, URLRequest) throws -> (URLResponse, Data)) = failTest

    // https://github.com/realm/SwiftLint/issues/6491
    // swiftlint:disable:next unneeded_throws_rethrows
    static func failTest(url: URL, _: URLRequest) throws -> (HTTPURLResponse, Data) {
        Issue.record("Call network request which should not have been called")
        let response = HTTPURLResponse(url: url, statusCode: 500, httpVersion: nil, headerFields: nil)!
        return (response, Data())
    }

    func send(_ request: URLRequest, body: Data?, completion: (Data?, URLResponse?, Error?) -> Void) {
        var request = request
        request.httpBody = body
        if let body {
            request.httpBodyStream = InputStream(data: body)
        }
        do {
            let (response, data) = try handleRequest(request)
            completion(data, response, nil)
        } catch {
            completion(nil, nil, error)
        }
    }

    private func handleRequest(_ request: URLRequest) throws -> (URLResponse, Data) {
        guard let url = request.url else {
            throw URLError(.badURL)
        }
        if url.path.contains("/oauth/v2/token") && request.httpMethod == "POST" {
            return try newTokenRequestHandler(url, request)
        }
        if url.path.contains("/oauth/v2/token/info") && request.httpMethod == "GET" {
            return try tokenValidationRequestHandler(url, request)
        }
        if url.path.contains("/accounts") && request.httpMethod == "GET" {
            return try accountsRequestHandler(url, request)
        }
        if url.path.contains("/transactions") && request.httpMethod == "GET" {
            return try transactionsRequestHandler(url, request)
        }
        if url.path.contains("/positions") && request.httpMethod == "GET" {
            return try positionsRequestHandler(url, request)
        }
        if url.path.contains("/graphql") && request.httpMethod == "POST" {
            return try graphQLRequestHandler(url, request)
        }
        Issue.record("Unexpected request: \(url)")
        throw URLError(.unsupportedURL)
    }
}

extension Data {
    init(reading input: InputStream) throws {
        self.init()
        input.open()
        defer {
            input.close()
        }
        let bufferSize = 4_096
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer {
            buffer.deallocate()
        }
        while input.hasBytesAvailable {
            let read = input.read(buffer, maxLength: bufferSize)
            if read < 0 {
                throw input.streamError!
            }
            if read == 0 {
                break
            }
            self.append(buffer, count: read)
        }
    }
}
