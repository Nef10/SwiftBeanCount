//
//  TokenTests.swift
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

@Suite
final class TokenTests: DownloaderTestCase { // swiftlint:disable:this type_body_length

    // MARK: - getToken with Credential Storage

    @Test
    func getTokenFromCredentialStorageWithValidToken() {
        let expectation = DispatchSemaphore(value: 0)

        mockHTTPClient.tokenValidationRequestHandler = { url, _ in
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        // Set up valid token data in credential storage
        mockCredentialStorage.storage["accessToken"] = "mock_access_token_12345"
        mockCredentialStorage.storage["refreshToken"] = "mock_refresh_token_67890"
        mockCredentialStorage.storage["expiry"] = String(Date().addingTimeInterval(3_600).timeIntervalSince1970)

        // This will just locally check expiry and do not do any network calls
        Token.getToken(from: mockCredentialStorage, dependencies: dependencies) { token in
            #expect(token != nil)
            expectation.signal()
        }

        #expect(expectation.wait(timeout: .now() + 10.0) == .success)
    }

    @Test
    func getTokenFromCredentialStorageWithMissingAccessToken() {
        let expectation = DispatchSemaphore(value: 0)

        mockCredentialStorage.storage["refreshToken"] = "test_refresh_token"
        mockCredentialStorage.storage["expiry"] = String(Date().addingTimeInterval(3_600).timeIntervalSince1970)

        Token.getToken(from: mockCredentialStorage, dependencies: dependencies) { token in
            #expect(token == nil)
            expectation.signal()
        }

        #expect(expectation.wait(timeout: .now() + 1.0) == .success)
    }

    @Test
    func getTokenFromCredentialStorageWithMissingRefreshToken() {
        let expectation = DispatchSemaphore(value: 0)

        mockCredentialStorage.storage["accessToken"] = "test_access_token"
        mockCredentialStorage.storage["expiry"] = String(Date().addingTimeInterval(3_600).timeIntervalSince1970)

        Token.getToken(from: mockCredentialStorage, dependencies: dependencies) { token in
            #expect(token == nil)
            expectation.signal()
        }

        #expect(expectation.wait(timeout: .now() + 1.0) == .success)
    }

    @Test
    func getTokenFromCredentialStorageWithMissingExpiry() {
        let expectation = DispatchSemaphore(value: 0)

        mockCredentialStorage.storage["accessToken"] = "test_access_token"
        mockCredentialStorage.storage["refreshToken"] = "test_refresh_token"

        Token.getToken(from: mockCredentialStorage, dependencies: dependencies) { token in
            #expect(token == nil)
            expectation.signal()
        }

        #expect(expectation.wait(timeout: .now() + 1.0) == .success)
    }

    @Test
    func getTokenFromCredentialStorageWithInvalidExpiry() {
        let expectation = DispatchSemaphore(value: 0)

        mockCredentialStorage.storage["accessToken"] = "test_access_token"
        mockCredentialStorage.storage["refreshToken"] = "test_refresh_token"
        mockCredentialStorage.storage["expiry"] = "invalid_date"

        Token.getToken(from: mockCredentialStorage, dependencies: dependencies) { token in
            #expect(token == nil)
            expectation.signal()
        }

        #expect(expectation.wait(timeout: .now() + 1.0) == .success)
    }

    @Test
    func expiredTokenFailsRefresh() {
        let requestExpectation = DispatchSemaphore(value: 0)
        let getTokenExpectation = DispatchSemaphore(value: 0)

        mockHTTPClient.newTokenRequestHandler = { url, _ in
            requestExpectation.signal()
            let response = HTTPURLResponse(url: url, statusCode: 401, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        mockCredentialStorage.storage["accessToken"] = "expired_token"
        mockCredentialStorage.storage["refreshToken"] = "refresh_token"
        mockCredentialStorage.storage["expiry"] = String(Date().addingTimeInterval(-3_600).timeIntervalSince1970)

        Token.getToken(from: mockCredentialStorage, dependencies: dependencies) { token in
            #expect(token == nil)
            getTokenExpectation.signal()
        }

        #expect(getTokenExpectation.wait(timeout: .now() + 10.0) == .success)
        #expect(requestExpectation.wait(timeout: .now() + 10.0) == .success)
    }

    @Test
    func expiredTokenRefreshFailsValidation() {
        let refreshExpectation = DispatchSemaphore(value: 0)
        let validateExpectation = DispatchSemaphore(value: 0)
        let getTokenExpectation = DispatchSemaphore(value: 0)

        mockHTTPClient.newTokenRequestHandler = { url, _ in
            refreshExpectation.signal()
            let jsonResponse = [
                "access_token": "atoken12345", "refresh_token": "rtoken67890", "expires_in": 3_600, "created_at": Int(Date().timeIntervalSince1970), "token_type": "Bearer"
            ]
            return (HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!, try JSONSerialization.data(withJSONObject: jsonResponse, options: []))
        }
        mockHTTPClient.tokenValidationRequestHandler = { _, _ in
            validateExpectation.signal()
            throw URLError(.networkConnectionLost)
        }

        mockCredentialStorage.storage["accessToken"] = "expired_token"
        mockCredentialStorage.storage["refreshToken"] = "refresh_token"
        mockCredentialStorage.storage["expiry"] = String(Date().addingTimeInterval(-3_600).timeIntervalSince1970)

        Token.getToken(from: mockCredentialStorage, dependencies: dependencies) { token in
            #expect(token == nil)
            getTokenExpectation.signal()
        }

        #expect(getTokenExpectation.wait(timeout: .now() + 10.0) == .success)
        #expect(refreshExpectation.wait(timeout: .now() + 10.0) == .success)
        #expect(validateExpectation.wait(timeout: .now() + 10.0) == .success)
    }

    @Test
    func expiredTokenRefreshFailsValidationWithWrongResponseType() {
        let refreshExpectation = DispatchSemaphore(value: 0)
        let validateExpectation = DispatchSemaphore(value: 0)
        let getTokenExpectation = DispatchSemaphore(value: 0)

        mockHTTPClient.newTokenRequestHandler = { url, _ in
            refreshExpectation.signal()
            let jsonResponse = [
                "access_token": "atoken12345", "refresh_token": "rtoken67890", "expires_in": 3_600, "created_at": Int(Date().timeIntervalSince1970), "token_type": "Bearer"
            ]
            return (HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!, try JSONSerialization.data(withJSONObject: jsonResponse, options: []))
        }
        mockHTTPClient.tokenValidationRequestHandler = { url, _ in
            validateExpectation.signal()
            return (URLResponse(url: url, mimeType: nil, expectedContentLength: 0, textEncodingName: nil), Data())
        }

        mockCredentialStorage.storage["accessToken"] = "expired_token"
        mockCredentialStorage.storage["refreshToken"] = "refresh_token"
        mockCredentialStorage.storage["expiry"] = String(Date().addingTimeInterval(-3_600).timeIntervalSince1970)

        Token.getToken(from: mockCredentialStorage, dependencies: dependencies) { token in
            #expect(token == nil)
            getTokenExpectation.signal()
        }

        #expect(getTokenExpectation.wait(timeout: .now() + 10.0) == .success)
        #expect(refreshExpectation.wait(timeout: .now() + 10.0) == .success)
        #expect(validateExpectation.wait(timeout: .now() + 10.0) == .success)
    }

    @Test
    func expiredTokenRefresh() { // swiftlint:disable:this function_body_length
        let refreshExpectation = DispatchSemaphore(value: 0)
        let validateExpectation = DispatchSemaphore(value: 0)
        let getTokenExpectation = DispatchSemaphore(value: 0)

        mockHTTPClient.newTokenRequestHandler = { url, request in
            #if canImport(FoundationNetworking)
            // body seems to be missing?
            #else
            // get JSON from POST request body stream
            let inputData = try Data(reading: request.httpBodyStream!), json = try JSONSerialization.jsonObject(with: inputData, options: []) as? [String: Any]
            #expect(json?["grant_type"] as? String == "refresh_token")
            #expect(json?["refresh_token"] as? String == "refresh_token_234")
            #expect(json?["client_id"] as? String == "4da53ac2b03225bed1550eba8e4611e086c7b905a3855e6ed12ea08c246758fa")
            #endif
            refreshExpectation.signal()
            return (HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!, try JSONSerialization.data(withJSONObject: [
                "access_token": "a34324532", "refresh_token": "r432432", "expires_in": 3_600, "created_at": Int(Date().timeIntervalSince1970), "token_type": "Bearer"
            ], options: []))
        }
        mockHTTPClient.tokenValidationRequestHandler = { url, request in
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer a34324532")
            validateExpectation.signal()
            return (HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data())
        }

        mockCredentialStorage.storage["accessToken"] = "expired_token"
        mockCredentialStorage.storage["refreshToken"] = "refresh_token_234"
        mockCredentialStorage.storage["expiry"] = String(Date().addingTimeInterval(-3_600).timeIntervalSince1970)

        Token.getToken(from: mockCredentialStorage, dependencies: dependencies) { token in
            #expect(token != nil)
            getTokenExpectation.signal()
        }

        #expect(getTokenExpectation.wait(timeout: .now() + 10.0) == .success)
        #expect(refreshExpectation.wait(timeout: .now() + 10.0) == .success)
        #expect(validateExpectation.wait(timeout: .now() + 10.0) == .success)

        #expect(mockCredentialStorage.read("accessToken") == "a34324532")
        #expect(mockCredentialStorage.read("refreshToken") == "r432432")
    }

    @Test
    func tokenInitMissingParameter() {
        let refreshExpectation = DispatchSemaphore(value: 0)
        let getTokenExpectation = DispatchSemaphore(value: 0)

        mockHTTPClient.newTokenRequestHandler = { url, _ in
            refreshExpectation.signal()
            let jsonResponse = [
                "refresh_token": "rtoken67890", "expires_in": 3_600, "created_at": Int(Date().timeIntervalSince1970), "token_type": "Bearer"
            ]
            return (HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!, try JSONSerialization.data(withJSONObject: jsonResponse, options: []))
        }
        mockCredentialStorage.storage["accessToken"] = "expired_token"
        mockCredentialStorage.storage["refreshToken"] = "refresh_token"
        mockCredentialStorage.storage["expiry"] = String(Date().addingTimeInterval(-3_600).timeIntervalSince1970)

        Token.getToken(from: mockCredentialStorage, dependencies: dependencies) { token in
            #expect(token == nil)
            getTokenExpectation.signal()
        }

        #expect(getTokenExpectation.wait(timeout: .now() + 10.0) == .success)
        #expect(refreshExpectation.wait(timeout: .now() + 10.0) == .success)
    }

    // MARK: - getToken with Username/Password/OTP

    @Test
    func getTokenWithUsernamePasswordOTPSuccess() {

        let tokenExpectation = DispatchSemaphore(value: 0), mockExpectation = DispatchSemaphore(value: 0)
        mockHTTPClient.newTokenRequestHandler = { url, request in
            #expect(request.value(forHTTPHeaderField: "x-wealthsimple-otp") == "123456")
            #if canImport(FoundationNetworking)
            // body seems to be missing?
            #else
            // get JSON from POST request body stream
            let inputData = try Data(reading: request.httpBodyStream!), json = try JSONSerialization.jsonObject(with: inputData, options: []) as? [String: Any]
            #expect(json?["username"] as? String == "test@example.com")
            #expect(json?["password"] as? String == "password1")
            #expect(json?["grant_type"] as? String == "password")
            #expect(json?["client_id"] as? String == "4da53ac2b03225bed1550eba8e4611e086c7b905a3855e6ed12ea08c246758fa")
            #expect(json?["scope"] as? String == "read")
            #endif
            let jsonResponse = [
                "access_token": "atoken12345", "refresh_token": "rtoken67890", "expires_in": 3_600, "created_at": Int(Date().timeIntervalSince1970), "token_type": "Bearer"
            ]
            mockExpectation.signal()
            return (HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!, try JSONSerialization.data(withJSONObject: jsonResponse, options: []))
        }

        Token.getToken(username: "test@example.com", password: "password1", otp: "123456", credentialStorage: mockCredentialStorage, dependencies: dependencies) { result in
            if case .success = result {
                // Verify token was saved to credential storage
                #expect(self.mockCredentialStorage.read("accessToken") == "atoken12345")
                #expect(self.mockCredentialStorage.read("refreshToken") == "rtoken67890")
                #expect(self.mockCredentialStorage.read("expiry") != nil)
                tokenExpectation.signal()
            } else {
                Issue.record("Expected success but got error")
            }
        }

        #expect(mockExpectation.wait(timeout: .now() + 10.0) == .success)
        #expect(tokenExpectation.wait(timeout: .now() + 10.0) == .success)
    }

    @Test
    func getTokenWithUsernamePasswordOTPNetworkFailure() {
        let tokenExpectation = DispatchSemaphore(value: 0)
        let serverExpectation = DispatchSemaphore(value: 0)

        // Set up the mock to throw an error for this test
        mockHTTPClient.newTokenRequestHandler = { _, _ in
            serverExpectation.signal()
            throw URLError(.networkConnectionLost)
        }

        Token.getToken(
            username: "test@example.com",
            password: "password",
            otp: "123456",
            credentialStorage: mockCredentialStorage,
            dependencies: dependencies
        ) { result in
            switch result {
            case .success:
                Issue.record("Expected failure due to network error")
            case .failure:
                break
            }
            tokenExpectation.signal()
        }

        #expect(tokenExpectation.wait(timeout: .now() + 10.0) == .success)
        #expect(serverExpectation.wait(timeout: .now() + 10.0) == .success)
    }

    @Test
    func getTokenWithWrongResponseType() {
        let tokenExpectation = DispatchSemaphore(value: 0)
        let serverExpectation = DispatchSemaphore(value: 0)

        // Set up the mock to return an URLResponse which is not a HTTPURLResponse for this test
        mockHTTPClient.newTokenRequestHandler = { url, _ in
            serverExpectation.signal()
            return (URLResponse(url: url, mimeType: nil, expectedContentLength: 0, textEncodingName: nil), Data())
        }

        Token.getToken(
            username: "test@example.com",
            password: "password",
            otp: "123456",
            credentialStorage: mockCredentialStorage,
            dependencies: dependencies
        ) { result in
            switch result {
            case .success:
                Issue.record("Expected failure due to wrong response type")
            case .failure:
                break
            }
            tokenExpectation.signal()
        }

        #expect(tokenExpectation.wait(timeout: .now() + 10.0) == .success)
        #expect(serverExpectation.wait(timeout: .now() + 10.0) == .success)
    }

    @Test
    func getTokenWithInvalidJSON() {
        let tokenExpectation = DispatchSemaphore(value: 0)
        let serverExpectation = DispatchSemaphore(value: 0)

        // Set up the mock to throw return an URLResponse which is not a HTTPURLResponse for this test
        mockHTTPClient.newTokenRequestHandler = { url, _ in
            serverExpectation.signal()
            return (HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data("NOT JSON".utf8))
        }

        Token.getToken(
            username: "test@example.com",
            password: "password",
            otp: "123456",
            credentialStorage: mockCredentialStorage,
            dependencies: dependencies
        ) { result in
            switch result {
            case .success:
                Issue.record("Expected failure due to wrong response type")
            case .failure:
                break
            }
            tokenExpectation.signal()
        }

        #expect(tokenExpectation.wait(timeout: .now() + 10.0) == .success)
        #expect(serverExpectation.wait(timeout: .now() + 10.0) == .success)
    }

}
