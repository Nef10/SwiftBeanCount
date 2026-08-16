//
//  WealthsimpleAccountTests.swift
//
//
//  Created by Steffen Kötte on 2025-09-02.
//

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Testing
@testable import WealthsimpleDownloader

@Suite
final class WealthsimpleAccountTests: DownloaderTestCase {

    // MARK: - Helper Methods

    private func createValidToken() throws -> Token {
        let expectation = DispatchSemaphore(value: 0)
        var resultToken: Token?

        mockHTTPClient.tokenValidationRequestHandler = { url, _ in
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        mockCredentialStorage.storage["accessToken"] = "valid_access_token1"
        mockCredentialStorage.storage["refreshToken"] = "valid_refresh_token"
        mockCredentialStorage.storage["expiry"] = String(Date().addingTimeInterval(3_600).timeIntervalSince1970)

        Token.getToken(from: mockCredentialStorage, dependencies: dependencies) { token in
            resultToken = token
            expectation.signal()
        }

        #expect(expectation.wait(timeout: .now() + 10.0) == .success)
        guard let resultToken else {
            Issue.record("Did not get valid token")
            throw TokenError.noToken
        }
        return resultToken
    }

    private func setupMockForSuccess(accounts: [[String: Any]], expectation: DispatchSemaphore) {
        mockHTTPClient.accountsRequestHandler = { url, request in
            #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer valid_access_token1")

            let jsonResponse = [
                "object": "account",
                "results": accounts
            ]
            expectation.signal()
            return (HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                    try JSONSerialization.data(withJSONObject: jsonResponse, options: []))
        }
    }

    private func testAccountsFailure(response: (URLResponse, Data), expectedError: AccountError) throws {

        let mockExpectation = DispatchSemaphore(value: 0)
        try testAccountsFailure(
            response: { _, _ in
                mockExpectation.signal()
                return response
            },
            expectedError: expectedError
        )

        #expect(mockExpectation.wait(timeout: .now() + 10.0) == .success)

    }

    private func testAccountsFailure(
        response: @escaping ((URL, URLRequest) throws -> (URLResponse, Data)),
        expectedError: AccountError
    ) throws {
        let expectation = DispatchSemaphore(value: 0)

        mockHTTPClient.accountsRequestHandler = response

        WealthsimpleAccount.getAccounts(token: try createValidToken(), dependencies: dependencies) { result in
            switch result {
            case .success:
                Issue.record("Expected failure")
            case .failure(let error):
                #expect(error == expectedError)
            }
            expectation.signal()
        }

        #expect(expectation.wait(timeout: .now() + 10.0) == .success)
    }

    private func testJSONParsingFailure(jsonData: Data, expectedError: AccountError) throws {
        try testAccountsFailure(response: (
                HTTPURLResponse(url: URL(string: "http://test.com")!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                jsonData
            ),
            expectedError: expectedError)
    }

    private func testJSONParsingFailure(jsonObject: [String: Any], expectedError: AccountError) throws {
        guard let jsonData = try? JSONSerialization.data(withJSONObject: jsonObject, options: []) else {
            Issue.record("Failed to create JSON data")
            return
        }
        try testJSONParsingFailure(jsonData: jsonData, expectedError: expectedError)
    }

    // MARK: - Successful getAccounts Tests

    @Test
    func getAccountsSuccess() throws {
        let expectation = DispatchSemaphore(value: 0)

        let mockExpectation = DispatchSemaphore(value: 0)
        setupMockForSuccess(accounts:
            [
                ["id": "account-123", "type": "ca_tfsa", "object": "account", "base_currency": "CAD", "custodian_account_number": "12345-67890"],
                ["id": "account-456", "type": "ca_rrsp", "object": "account", "base_currency": "USD", "custodian_account_number": "98765-43210"]
            ],
            expectation: mockExpectation
        )

        WealthsimpleAccount.getAccounts(token: try createValidToken(), dependencies: dependencies) { result in
            switch result {
            case .success(let accounts):
                #expect(accounts.count == 2)

                let firstAccount = accounts[0]
                #expect(firstAccount.id == "account-123")
                #expect(firstAccount.accountType == .tfsa)
                #expect(firstAccount.currency == "CAD")
                #expect(firstAccount.number == "12345-67890")

                let secondAccount = accounts[1]
                #expect(secondAccount.id == "account-456")
                #expect(secondAccount.accountType == .rrsp)
                #expect(secondAccount.currency == "USD")
                #expect(secondAccount.number == "98765-43210")

            case .failure(let error):
                Issue.record("Expected success but got error: \(error)")
            }
            expectation.signal()
        }

        #expect(expectation.wait(timeout: .now() + 10.0) == .success)
        #expect(mockExpectation.wait(timeout: .now() + 10.0) == .success)
    }

    @Test
    func getAccountsEmptyResults() throws {
        let expectation = DispatchSemaphore(value: 0)
        let mockExpectation = DispatchSemaphore(value: 0)

        setupMockForSuccess(accounts: [], expectation: mockExpectation)

        WealthsimpleAccount.getAccounts(token: try createValidToken(), dependencies: dependencies) { result in
            switch result {
            case .success(let accounts):
                #expect(accounts.isEmpty)
            case .failure(let error):
                Issue.record("Expected success but got error: \(error)")
            }
            expectation.signal()
        }

        #expect(expectation.wait(timeout: .now() + 10.0) == .success)
        #expect(mockExpectation.wait(timeout: .now() + 10.0) == .success)
    }

    // MARK: - Network Error Tests

#if canImport(FoundationNetworking)
    @Test
    func getAccountsNetworkFailure() throws {
        try testAccountsFailure(
            response: { _, _ in
                throw URLError(.networkConnectionLost)
            }, expectedError: AccountError.httpError(error: "The operation could not be completed. (NSURLErrorDomain error -1005.)")
        )
    }
#else
    @Test
    func getAccountsNetworkFailure() throws {
        try testAccountsFailure(
            response: { _, _ in
                throw URLError(.networkConnectionLost)
            }, expectedError: AccountError.httpError(error: "The operation couldn’t be completed. (NSURLErrorDomain error -1005.)")
        )
    }
#endif

    @Test
    func getAccountsInvalidJSONEmptyData() throws {
        try testAccountsFailure(response: (
                HTTPURLResponse(url: URL(string: "http://test.com")!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                Data()
            ), expectedError: AccountError.invalidJson(json: Data())
        )
    }

    @Test
    func getAccountsWrongResponseType() throws {
        try testAccountsFailure(response: (
            URLResponse(url: URL(string: "http://test.com")!, mimeType: nil, expectedContentLength: 0, textEncodingName: nil),
            Data("test".utf8)
        ), expectedError: AccountError.httpError(error: "No HTTPURLResponse"))
    }

    @Test
    func getAccountsHTTPError() throws {
        try testAccountsFailure(response: (
            HTTPURLResponse(url: URL(string: "http://test.com")!, statusCode: 401, httpVersion: nil, headerFields: nil)!,
            Data()
        ), expectedError: AccountError.httpError(error: "Status code 401"))
    }

    // MARK: - JSON Parsing Error Tests

    @Test
    func getAccountsInvalidJSON() throws {
        let data = Data("NOT VALID JSON".utf8)
        try testJSONParsingFailure(
            jsonData: data,
            expectedError: AccountError.invalidJson(json: data)
        )
    }

    @Test
    func getAccountsInvalidJSONType() throws {
        guard let jsonData = try? JSONSerialization.data(withJSONObject: ["not", "a", "dictionary"], options: []) else {
            Issue.record("Failed to create test JSON data")
            return
        }
        try testJSONParsingFailure(
            jsonData: jsonData,
            expectedError: AccountError.invalidJson(json: jsonData)
        )
    }

    @Test
    func getAccountsMissingResults() throws {
        try testJSONParsingFailure(jsonObject: ["object": "account"], expectedError: AccountError.missingResultParamenter(json: "{\"object\":\"account\"}"))
    }

    @Test
    func getAccountsInvalidObject() throws {
        try testJSONParsingFailure(
            jsonObject: ["object": "not_account", "results": []],
            expectedError: AccountError.invalidResultParamenter(json: "{\"object\":\"not_account\",\"results\":[]}")
        )
    }

    @Test
    func getAccountsMissingAccountId() throws {
        try testJSONParsingFailure(jsonObject: [
            "object": "account",
            "results": [
                [
                    "type": "ca_tfsa",
                    "object": "account",
                    "base_currency": "CAD",
                    "custodian_account_number": "12345"
                ]
            ]
        ], expectedError: AccountError.missingResultParamenter(
            json: "{\"base_currency\":\"CAD\",\"custodian_account_number\":\"12345\",\"object\":\"account\",\"type\":\"ca_tfsa\"}"
        ))
    }

    @Test
    func getAccountsInvalidAccountType() throws {
        try testJSONParsingFailure(jsonObject: [
            "object": "account",
            "results": [
                [
                    "id": "account-123",
                    "type": "invalid_account_type",
                    "object": "account",
                    "base_currency": "CAD",
                    "custodian_account_number": "12345"
                ]
            ]
        ], expectedError: AccountError.invalidResultParamenter(json:
            "{\"base_currency\":\"CAD\",\"custodian_account_number\":\"12345\",\"id\":\"account-123\",\"object\":\"account\",\"type\":\"invalid_account_type\"}"
        ))
    }

    @Test
    func getAccountsInvalidAccountObject() throws {
        try testJSONParsingFailure(jsonObject: [
            "object": "account",
            "results": [
                [
                    "id": "account-123",
                    "type": "ca_tfsa",
                    "object": "not_account",
                    "base_currency": "CAD",
                    "custodian_account_number": "12345"
                ]
            ]
        ], expectedError: AccountError.invalidResultParamenter(
            json: "{\"base_currency\":\"CAD\",\"custodian_account_number\":\"12345\",\"id\":\"account-123\",\"object\":\"not_account\",\"type\":\"ca_tfsa\"}"
        ))
    }

}
