// swiftlint:disable file_length
//
//  WealthsimpleDownloaderTests.swift
//
//
//  Created by Steffen Kötte on 2025-09-02.
//

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import WealthsimpleDownloader
import Testing

@Suite
final class WealthsimpleDownloaderTests: DownloaderTestCase { // swiftlint:disable:this type_body_length

    private let mockAccount = MockAccount(id: "account-123", accountType: .tfsa, currency: "CAD", number: "12345")

    private var downloader: WealthsimpleAPI!

    // MARK: - Helper Methods

    private func createDownloader(withAuthCallback callback: @escaping WealthsimpleAPI.AuthenticationCallback) -> WealthsimpleAPI {
        WealthsimpleAPI(authenticationCallback: callback, credentialStorage: mockCredentialStorage)
    }

    private func authenticateDownloader() {
        let expectation = XCTestExpectation(description: "authenticate finished")

        MockURLProtocol.tokenValidationRequestHandler = { url, _ in
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        // Set valid token in credential storage
        mockCredentialStorage.storage["accessToken"] = "valid_access_token"
        mockCredentialStorage.storage["refreshToken"] = "valid_refresh_token"
        mockCredentialStorage.storage["expiry"] = String(Date().addingTimeInterval(3_600).timeIntervalSince1970)

        downloader = createDownloader { _ in
            XCTFail("Auth callback should not be called when credential storage has valid token")
        }

        // Authenticate first to get token into downloader
        downloader.authenticate { error in
            XCTAssertNil(error)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 10.0)
    }

    // MARK: - Constructor Tests

    @Test
    func testInit() {
        let downloader = createDownloader { _ in
            XCTFail("Auth callback should not be called")
        }
        XCTAssertNotNil(downloader)
    }

    // MARK: - Authenticate Tests

    @Test
    func testAuthenticateWithExistingTokenSuccess() {
        authenticateDownloader()
    }

    @Test
    func testAuthenticateTwice() {
        let expectation = XCTestExpectation(description: "authenticate completion")

        authenticateDownloader()

        downloader.authenticate { error in
            XCTAssertNil(error)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 10.0)
    }

    @Test
    func testAuthenticateWithExistingTokenRefreshRequired() {
        let expectation = XCTestExpectation(description: "authenticate completion")

        downloader = createDownloader { _ in XCTFail("Should not request credentials for refresh") }

        MockURLProtocol.tokenValidationRequestHandler = { url, _ in
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        MockURLProtocol.newTokenRequestHandler = { url, request in
            #if canImport(FoundationNetworking)
            // body seems to be missing?
            #else
            let inputData = try Data(reading: request.httpBodyStream!), json = try JSONSerialization.jsonObject(with: inputData, options: []) as? [String: Any]
            XCTAssertEqual(json?["grant_type"] as? String, "refresh_token")
            XCTAssertEqual(json?["refresh_token"] as? String, "valid_refresh_token3")
            #endif
            let jsonResponse = [
                "access_token": "new_access_token",
                "refresh_token": "new_refresh_token",
                "expires_in": 3_600,
                "created_at": Int(Date().timeIntervalSince1970),
                "token_type": "Bearer"
            ]
            return (HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!, try JSONSerialization.data(withJSONObject: jsonResponse, options: []))
        }

        // Set expired token - this will trigger getNewToken since no valid token in storage
        mockCredentialStorage.storage["accessToken"] = "expired_access_token"
        mockCredentialStorage.storage["refreshToken"] = "valid_refresh_token3"
        mockCredentialStorage.storage["expiry"] = String(Date().addingTimeInterval(-3_600).timeIntervalSince1970)

        downloader.authenticate { error in
            XCTAssertNil(error)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 10.0)
    }

    @Test
    func testAuthenticateWithoutToken() {
        let expectation = XCTestExpectation(description: "authenticate completion")
        let authExpectation = XCTestExpectation(description: "auth callback called")

        downloader = createDownloader { completion in
            authExpectation.fulfill()
            completion("testuser", "testpass", "654321")
        }

        MockURLProtocol.newTokenRequestHandler = { url, request in
            XCTAssertEqual(request.value(forHTTPHeaderField: "x-wealthsimple-otp"), "654321")
            #if canImport(FoundationNetworking)
            // body seems to be missing?
            #else
            let inputData = try Data(reading: request.httpBodyStream!), json = try JSONSerialization.jsonObject(with: inputData, options: []) as? [String: Any]
            XCTAssertEqual(json?["grant_type"] as? String, "password")
            XCTAssertEqual(json?["username"] as? String, "testuser")
            XCTAssertEqual(json?["password"] as? String, "testpass")
            #endif
            let jsonResponse = [
                "access_token": "new_access_token7",
                "refresh_token": "new_refresh_token8",
                "expires_in": 3_600,
                "created_at": Int(Date().timeIntervalSince1970),
                "token_type": "Bearer"
            ]
            return (HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!, try JSONSerialization.data(withJSONObject: jsonResponse, options: []))
        }

        downloader.authenticate { error in
            XCTAssertNil(error)
            expectation.fulfill()
        }

        wait(for: [expectation, authExpectation], timeout: 10.0)
    }

    @Test
    func testAuthenticateWithNewTokenFailure() {
        let expectation = XCTestExpectation(description: "authenticate completion")
        let authExpectation = XCTestExpectation(description: "auth callback called")

        let authCallback: WealthsimpleAPI.AuthenticationCallback = { completion in
            authExpectation.fulfill()
            completion("testuser", "testpass", "123456")
        }

        downloader = createDownloader(withAuthCallback: authCallback)

        MockURLProtocol.newTokenRequestHandler = { _, _ in
            throw URLError(.networkConnectionLost)
        }

        downloader.authenticate { error in
            XCTAssertNotNil(error)
            expectation.fulfill()
        }

        wait(for: [expectation, authExpectation], timeout: 10.0)
    }

    // MARK: - getAccounts Tests

    @Test
    func testGetAccountsWithoutToken() {
        let expectation = XCTestExpectation(description: "getAccounts completion")

        downloader = createDownloader { _ in
            XCTFail("Auth callback should not be called without a call to authenticate")
        }

        downloader.getAccounts { result in
            switch result {
            case .success:
                XCTFail("Expected failure due to no token")
            case .failure(let error):
                if case .tokenError(let tokenError) = error {
                    XCTAssertEqual(tokenError, .noToken)
                } else {
                    XCTFail("Expected tokenError(.noToken)")
                }
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 10.0)
    }

    @Test
    func testGetAccountsWithTokenSuccess() throws {
        let expectation = XCTestExpectation(description: "getAccounts completion")
        let mockExpectation = XCTestExpectation(description: "mock server called")

        authenticateDownloader()

        // Setup mock for successful accounts response
        MockURLProtocol.accountsRequestHandler = { url, request in
            XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer valid_access_token")

            let jsonResponse = [
                "object": "account",
                "results": [
                    ["id": "account-123", "type": "ca_tfsa", "object": "account", "base_currency": "CAD", "custodian_account_number": "12345-67890"]
                ]
            ]
            mockExpectation.fulfill()
            return (HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!, try JSONSerialization.data(withJSONObject: jsonResponse, options: []))
        }

        downloader.getAccounts { result in
            switch result {
            case .success(let accounts):
                XCTAssertEqual(accounts.count, 1)
                XCTAssertEqual(accounts[0].id, "account-123")
            case .failure:
                XCTFail("Expected success")
            }
            expectation.fulfill()
        }

        wait(for: [expectation, mockExpectation], timeout: 10.0)
    }

    // https://github.com/realm/SwiftLint/issues/6491
    // swiftlint:disable:next unneeded_throws_rethrows
    @Test
    func testGetAccountsWithHttpError() throws {
        let expectation = XCTestExpectation(description: "getAccounts completion")
        let mockExpectation = XCTestExpectation(description: "mock server called")

        authenticateDownloader()

        // Setup mock to return HTTP error
        MockURLProtocol.accountsRequestHandler = { url, _ in
            mockExpectation.fulfill()
            return (HTTPURLResponse(url: url, statusCode: 401, httpVersion: nil, headerFields: nil)!, Data())
        }

        downloader.getAccounts { result in
            switch result {
            case .success:
                XCTFail("Expected failure")
            case .failure(let error):
                if case .httpError = error {
                    // This is expected
                } else {
                    XCTFail("Expected httpError but got \(error)")
                }
            }
            expectation.fulfill()
        }

        wait(for: [expectation, mockExpectation], timeout: 10.0)
    }

    // MARK: - getPositions Tests

    @Test
    func testGetPositionsWithoutToken() {
        let expectation = XCTestExpectation(description: "getPositions completion")

        downloader = createDownloader { _ in
            XCTFail("Auth callback should not be called without a call to authenticate")
        }

        downloader.getPositions(in: mockAccount, date: nil) { result in
            switch result {
            case .success:
                XCTFail("Expected failure due to no token")
            case .failure(let error):
                if case .tokenError(let tokenError) = error {
                    XCTAssertEqual(tokenError, .noToken)
                } else {
                    XCTFail("Expected tokenError(.noToken)")
                }
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 10.0)
    }

    @Test
    func testGetPositionsWithTokenSuccess() throws {
        let expectation = XCTestExpectation(description: "getPositions completion"), mockExpectation = XCTestExpectation(description: "mock server called")

        authenticateDownloader()

        // Setup mock for successful positions response
        MockURLProtocol.positionsRequestHandler = { url, _ in
            XCTAssert((url.query ?? "").contains("account_id=\(self.mockAccount.id)"))
            let jsonResponse = [
                "object": "position",
                "results": [
                    [
                        "id": "position-123",
                        "object": "position",
                        "account_id": "account-123",
                        "quantity": "10.0",
                        "market_price": ["amount": "110.0", "currency": "CAD"],
                        "position_date": "2024-01-01",
                        "asset": [ "security_id": "asset-123", "object": "asset", "currency": "CAD", "symbol": "DEF", "name": "ABC ETF", "type": "exchange_traded_fund" ]
                    ]
                ]
            ]
            mockExpectation.fulfill()
            return (HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!, try JSONSerialization.data(withJSONObject: jsonResponse, options: []))
        }

        downloader.getPositions(in: mockAccount, date: nil) { result in
            if case .success(let positions) = result {
                XCTAssertEqual(positions.count, 1)
            } else {
                XCTFail("Expected success")
            }
            expectation.fulfill()
        }

        wait(for: [expectation, mockExpectation], timeout: 10.0)
    }

    // MARK: - getTransactions Tests

    @Test
    func testGetTransactionsWithoutToken() {
        let expectation = XCTestExpectation(description: "getTransactions completion")

        downloader = createDownloader { _ in
            XCTFail("Auth callback should not be called without a call to authenticate")
        }

        let defaultDate = Date(timeIntervalSince1970: 0)
        downloader.getTransactions(in: mockAccount, startDate: defaultDate) { result in
            switch result {
            case .success:
                XCTFail("Expected failure due to no token")
            case .failure(let error):
                if case .tokenError(let tokenError) = error {
                    XCTAssertEqual(tokenError, .noToken)
                } else {
                    XCTFail("Expected tokenError(.noToken)")
                }
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 10.0)
    }

    @Test
    func testGetTransactionsWithTokenSuccess() throws { // swiftlint:disable:this function_body_length
        let expectation = XCTestExpectation(description: "getTransactions completion")
        let mockExpectation = XCTestExpectation(description: "mock server called")

        authenticateDownloader()

        // Setup mock for successful transactions response
        MockURLProtocol.transactionsRequestHandler = { url, request in
            XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer valid_access_token")

            let jsonResponse = [
                "object": "transaction",
                "results": [
                    [
                        "id": "transaction-123",
                        "object": "transaction",
                        "account_id": "account-123",
                        "description": "Test transaction",
                        "type": "buy",
                        "symbol": "XIC",
                        "quantity": "10.0",
                        "market_price": ["amount": "100.0", "currency": "CAD"],
                        "market_value": ["amount": "1000.0", "currency": "CAD"],
                        "net_cash": ["amount": "-1000.0", "currency": "CAD"],
                        "process_date": "2024-01-01",
                        "effective_date": "2024-01-01",
                        "fx_rate": "1.0"
                    ]
                ]
            ]
            mockExpectation.fulfill()
            return (HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!, try JSONSerialization.data(withJSONObject: jsonResponse, options: []))
        }

        let defaultDate = Date(timeIntervalSince1970: 0)
        downloader.getTransactions(in: mockAccount, startDate: defaultDate) { result in
            switch result {
            case .success(let transactions):
                XCTAssertEqual(transactions.count, 1)
            case .failure:
                XCTFail("Expected success")
            }
            expectation.fulfill()
        }

        wait(for: [expectation, mockExpectation], timeout: 10.0)
    }

    @Test
    func testGetTransactionsWithNetworkError() throws {
        let expectation = XCTestExpectation(description: "getTransactions completion")
        let mockExpectation = XCTestExpectation(description: "mock server called")

        authenticateDownloader()

        // Setup mock to throw network error
        MockURLProtocol.transactionsRequestHandler = { _, _ in
            mockExpectation.fulfill()
            throw URLError(.networkConnectionLost)
        }

        let defaultDate = Date(timeIntervalSince1970: 0)
        downloader.getTransactions(in: mockAccount, startDate: defaultDate) { result in
            switch result {
            case .success:
                XCTFail("Expected failure")
            case .failure(let error):
                if case .httpError = error {
                    // This is expected
                } else {
                    XCTFail("Expected httpError but got \(error)")
                }
            }
            expectation.fulfill()
        }

        wait(for: [expectation, mockExpectation], timeout: 10.0)
    }

}
