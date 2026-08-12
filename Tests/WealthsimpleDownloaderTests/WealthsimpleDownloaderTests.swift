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
import Testing
@testable import WealthsimpleDownloader
@Suite(.mockURLProtocolSerialized, .serialized)
final class WealthsimpleDownloaderTests: DownloaderTestCase { // swiftlint:disable:this type_body_length
   private let mockAccount = MockAccount(id: "account-123", accountType: .tfsa, currency: "CAD", number: "12345")
   private var downloader: WealthsimpleAPI!
   // MARK: - Helper Methods
   private func createDownloader(withAuthCallback callback: @escaping WealthsimpleAPI.AuthenticationCallback) -> WealthsimpleAPI {
       WealthsimpleAPI(authenticationCallback: callback, credentialStorage: mockCredentialStorage)
   }
   private func authenticateDownloader() {
       let expectation = DispatchSemaphore(value: 0)
       MockURLProtocol.tokenValidationRequestHandler = { url, _ in
           let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
           return (response, Data())
       }
       // Set valid token in credential storage
       mockCredentialStorage.storage["accessToken"] = "valid_access_token"
       mockCredentialStorage.storage["refreshToken"] = "valid_refresh_token"
       mockCredentialStorage.storage["expiry"] = String(Date().addingTimeInterval(3_600).timeIntervalSince1970)
       downloader = createDownloader { _ in
           Issue.record("Auth callback should not be called when credential storage has valid token")
       }
       // Authenticate first to get token into downloader
       downloader.authenticate { error in
           #expect(error == nil)
           expectation.signal()
       }
       #expect(expectation.wait(timeout: .now() + 10.0) == .success)
   }
   // MARK: - Constructor Tests
   @Test
   func initialization() {
       _ = createDownloader { _ in
           Issue.record("Auth callback should not be called")
       }
   }
   // MARK: - Authenticate Tests
   @Test
   func authenticateWithExistingTokenSuccess() {
       authenticateDownloader()
   }
   @Test
   func authenticateTwice() {
       let expectation = DispatchSemaphore(value: 0)
       authenticateDownloader()
       downloader.authenticate { error in
           #expect(error == nil)
           expectation.signal()
       }
       #expect(expectation.wait(timeout: .now() + 10.0) == .success)
   }
   @Test
   func authenticateWithExistingTokenRefreshRequired() {
       let expectation = DispatchSemaphore(value: 0)
       downloader = createDownloader { _ in Issue.record("Should not request credentials for refresh") }
       MockURLProtocol.tokenValidationRequestHandler = { url, _ in
           let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
           return (response, Data())
       }
       MockURLProtocol.newTokenRequestHandler = { url, request in
           #if canImport(FoundationNetworking)
           // body seems to be missing?
           #else
           let inputData = try Data(reading: request.httpBodyStream!), json = try JSONSerialization.jsonObject(with: inputData, options: []) as? [String: Any]
           #expect(json?["grant_type"] as? String == "refresh_token")
           #expect(json?["refresh_token"] as? String == "valid_refresh_token3")
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
           #expect(error == nil)
           expectation.signal()
       }
       #expect(expectation.wait(timeout: .now() + 10.0) == .success)
   }
   @Test
   func authenticateWithoutToken() {
       let expectation = DispatchSemaphore(value: 0)
       let authExpectation = DispatchSemaphore(value: 0)
       downloader = createDownloader { completion in
           authExpectation.signal()
           completion("testuser", "testpass", "654321")
       }
       MockURLProtocol.newTokenRequestHandler = { url, request in
           #expect(request.value(forHTTPHeaderField: "x-wealthsimple-otp") == "654321")
           #if canImport(FoundationNetworking)
           // body seems to be missing?
           #else
           let inputData = try Data(reading: request.httpBodyStream!), json = try JSONSerialization.jsonObject(with: inputData, options: []) as? [String: Any]
           #expect(json?["grant_type"] as? String == "password")
           #expect(json?["username"] as? String == "testuser")
           #expect(json?["password"] as? String == "testpass")
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
           #expect(error == nil)
           expectation.signal()
       }
       #expect(expectation.wait(timeout: .now() + 10.0) == .success)
       #expect(authExpectation.wait(timeout: .now() + 10.0) == .success)
   }
   @Test
   func authenticateWithNewTokenFailure() {
       let expectation = DispatchSemaphore(value: 0)
       let authExpectation = DispatchSemaphore(value: 0)
       let authCallback: WealthsimpleAPI.AuthenticationCallback = { completion in
           authExpectation.signal()
           completion("testuser", "testpass", "123456")
       }
       downloader = createDownloader(withAuthCallback: authCallback)
       MockURLProtocol.newTokenRequestHandler = { _, _ in
           throw URLError(.networkConnectionLost)
       }
       downloader.authenticate { error in
           #expect(error != nil)
           expectation.signal()
       }
       #expect(expectation.wait(timeout: .now() + 10.0) == .success)
       #expect(authExpectation.wait(timeout: .now() + 10.0) == .success)
   }
   // MARK: - getAccounts Tests
   @Test
   func getAccountsWithoutToken() {
       let expectation = DispatchSemaphore(value: 0)
       downloader = createDownloader { _ in
           Issue.record("Auth callback should not be called without a call to authenticate")
       }
       downloader.getAccounts { result in
           switch result {
           case .success:
               Issue.record("Expected failure due to no token")
           case .failure(let error):
               if case .tokenError(let tokenError) = error {
                   #expect(tokenError == .noToken)
               } else {
                   Issue.record("Expected tokenError(.noToken)")
               }
           }
           expectation.signal()
       }
       #expect(expectation.wait(timeout: .now() + 10.0) == .success)
   }
   @Test
   func getAccountsWithTokenSuccess() throws {
       let expectation = DispatchSemaphore(value: 0)
       let mockExpectation = DispatchSemaphore(value: 0)
       authenticateDownloader()
       // Setup mock for successful accounts response
       MockURLProtocol.accountsRequestHandler = { url, request in
           #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
           #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer valid_access_token")
           let jsonResponse = [
               "object": "account",
               "results": [
                   ["id": "account-123", "type": "ca_tfsa", "object": "account", "base_currency": "CAD", "custodian_account_number": "12345-67890"]
               ]
           ]
           mockExpectation.signal()
           return (HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!, try JSONSerialization.data(withJSONObject: jsonResponse, options: []))
       }
       downloader.getAccounts { result in
           switch result {
           case .success(let accounts):
               #expect(accounts.count == 1)
               #expect(accounts[0].id == "account-123")
           case .failure:
               Issue.record("Expected success")
           }
           expectation.signal()
       }
       #expect(expectation.wait(timeout: .now() + 10.0) == .success)
       #expect(mockExpectation.wait(timeout: .now() + 10.0) == .success)
   }
   @Test
   func getAccountsWithHttpError() {
       let expectation = DispatchSemaphore(value: 0)
       let mockExpectation = DispatchSemaphore(value: 0)
       authenticateDownloader()
       // Setup mock to return HTTP error
       MockURLProtocol.accountsRequestHandler = { url, _ in
           mockExpectation.signal()
           return (HTTPURLResponse(url: url, statusCode: 401, httpVersion: nil, headerFields: nil)!, Data())
       }
       downloader.getAccounts { result in
           switch result {
           case .success:
               Issue.record("Expected failure")
           case .failure(let error):
               if case .httpError = error {
                   // This is expected
               } else {
                   Issue.record("Expected httpError but got \(error)")
               }
           }
           expectation.signal()
       }
       #expect(expectation.wait(timeout: .now() + 10.0) == .success)
       #expect(mockExpectation.wait(timeout: .now() + 10.0) == .success)
   }
   // MARK: - getPositions Tests
   @Test
   func getPositionsWithoutToken() {
       let expectation = DispatchSemaphore(value: 0)
       downloader = createDownloader { _ in
           Issue.record("Auth callback should not be called without a call to authenticate")
       }
       downloader.getPositions(in: mockAccount, date: nil) { result in
           switch result {
           case .success:
               Issue.record("Expected failure due to no token")
           case .failure(let error):
               if case .tokenError(let tokenError) = error {
                   #expect(tokenError == .noToken)
               } else {
                   Issue.record("Expected tokenError(.noToken)")
               }
           }
           expectation.signal()
       }
       #expect(expectation.wait(timeout: .now() + 10.0) == .success)
   }
   @Test
   func getPositionsWithTokenSuccess() throws { // swiftlint:disable:this function_body_length
       let expectation = DispatchSemaphore(value: 0), mockExpectation = DispatchSemaphore(value: 0)
       authenticateDownloader()
       // Setup mock for successful positions response
       MockURLProtocol.positionsRequestHandler = { url, _ in
           #expect((url.query ?? "").contains("account_id=\(self.mockAccount.id)"))
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
           mockExpectation.signal()
           return (HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!, try JSONSerialization.data(withJSONObject: jsonResponse, options: []))
       }
       downloader.getPositions(in: mockAccount, date: nil) { result in
           if case .success(let positions) = result {
               #expect(positions.count == 1)
           } else {
               Issue.record("Expected success")
           }
           expectation.signal()
       }
       #expect(expectation.wait(timeout: .now() + 10.0) == .success)
       #expect(mockExpectation.wait(timeout: .now() + 10.0) == .success)
   }
   // MARK: - getTransactions Tests
   @Test
   func getTransactionsWithoutToken() {
       let expectation = DispatchSemaphore(value: 0)
       downloader = createDownloader { _ in
           Issue.record("Auth callback should not be called without a call to authenticate")
       }
       let defaultDate = Date(timeIntervalSince1970: 0)
       downloader.getTransactions(in: mockAccount, startDate: defaultDate) { result in
           switch result {
           case .success:
               Issue.record("Expected failure due to no token")
           case .failure(let error):
               if case .tokenError(let tokenError) = error {
                   #expect(tokenError == .noToken)
               } else {
                   Issue.record("Expected tokenError(.noToken)")
               }
           }
           expectation.signal()
       }
       #expect(expectation.wait(timeout: .now() + 10.0) == .success)
   }
   @Test
   func getTransactionsWithTokenSuccess() throws { // swiftlint:disable:this function_body_length
       let expectation = DispatchSemaphore(value: 0)
       let mockExpectation = DispatchSemaphore(value: 0)
       authenticateDownloader()
       // Setup mock for successful transactions response
       MockURLProtocol.transactionsRequestHandler = { url, request in
           #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
           #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer valid_access_token")
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
           mockExpectation.signal()
           return (HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!, try JSONSerialization.data(withJSONObject: jsonResponse, options: []))
       }
       let defaultDate = Date(timeIntervalSince1970: 0)
       downloader.getTransactions(in: mockAccount, startDate: defaultDate) { result in
           switch result {
           case .success(let transactions):
               #expect(transactions.count == 1)
           case .failure:
               Issue.record("Expected success")
           }
           expectation.signal()
       }
       #expect(expectation.wait(timeout: .now() + 10.0) == .success)
       #expect(mockExpectation.wait(timeout: .now() + 10.0) == .success)
   }
   @Test
   func getTransactionsWithNetworkError() throws {
       let expectation = DispatchSemaphore(value: 0)
       let mockExpectation = DispatchSemaphore(value: 0)
       authenticateDownloader()
       // Setup mock to throw network error
       MockURLProtocol.transactionsRequestHandler = { _, _ in
           mockExpectation.signal()
           throw URLError(.networkConnectionLost)
       }
       let defaultDate = Date(timeIntervalSince1970: 0)
       downloader.getTransactions(in: mockAccount, startDate: defaultDate) { result in
           switch result {
           case .success:
               Issue.record("Expected failure")
           case .failure(let error):
               if case .httpError = error {
                   // This is expected
               } else {
                   Issue.record("Expected httpError but got \(error)")
               }
           }
           expectation.signal()
       }
       #expect(expectation.wait(timeout: .now() + 10.0) == .success)
       #expect(mockExpectation.wait(timeout: .now() + 10.0) == .success)
   }
}
