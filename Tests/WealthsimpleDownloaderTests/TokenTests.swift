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

@Suite(.serialized)
final class TokenTests: DownloaderTestCase { // swiftlint:disable:this type_body_length

    // MARK: - getToken with Credential Storage

    @Test
    func testGetTokenFromCredentialStorageWithValidToken() {
        let expectation = TestExpectation(description: "getToken completion")

        MockURLProtocol.tokenValidationRequestHandler = { url, _ in
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        // Set up valid token data in credential storage
        mockCredentialStorage.storage["accessToken"] = "mock_access_token_12345"
        mockCredentialStorage.storage["refreshToken"] = "mock_refresh_token_67890"
        mockCredentialStorage.storage["expiry"] = String(Date().addingTimeInterval(3_600).timeIntervalSince1970)

        // This will just locally check expiry and do not do any network calls
        Token.getToken(from: mockCredentialStorage) { token in
            expectNotNil(token)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 10.0)
    }

    @Test
    func testGetTokenFromCredentialStorageWithMissingAccessToken() {
        let expectation = TestExpectation(description: "getToken completion")

        mockCredentialStorage.storage["refreshToken"] = "test_refresh_token"
        mockCredentialStorage.storage["expiry"] = String(Date().addingTimeInterval(3_600).timeIntervalSince1970)

        Token.getToken(from: mockCredentialStorage) { token in
            expectNil(token)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)
    }

    @Test
    func testGetTokenFromCredentialStorageWithMissingRefreshToken() {
        let expectation = TestExpectation(description: "getToken completion")

        mockCredentialStorage.storage["accessToken"] = "test_access_token"
        mockCredentialStorage.storage["expiry"] = String(Date().addingTimeInterval(3_600).timeIntervalSince1970)

        Token.getToken(from: mockCredentialStorage) { token in
            expectNil(token)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)
    }

    @Test
    func testGetTokenFromCredentialStorageWithMissingExpiry() {
        let expectation = TestExpectation(description: "getToken completion")

        mockCredentialStorage.storage["accessToken"] = "test_access_token"
        mockCredentialStorage.storage["refreshToken"] = "test_refresh_token"

        Token.getToken(from: mockCredentialStorage) { token in
            expectNil(token)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)
    }

    @Test
    func testGetTokenFromCredentialStorageWithInvalidExpiry() {
        let expectation = TestExpectation(description: "getToken completion")

        mockCredentialStorage.storage["accessToken"] = "test_access_token"
        mockCredentialStorage.storage["refreshToken"] = "test_refresh_token"
        mockCredentialStorage.storage["expiry"] = "invalid_date"

        Token.getToken(from: mockCredentialStorage) { token in
            expectNil(token)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)
    }

    @Test
    func testExpiredTokenFailsRefresh() {
        let requestExpectation = TestExpectation(description: "mock server called")
        let getTokenExpectation = TestExpectation(description: "getToken completion")

        MockURLProtocol.newTokenRequestHandler = { url, _ in
            requestExpectation.fulfill()
            let response = HTTPURLResponse(url: url, statusCode: 401, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        mockCredentialStorage.storage["accessToken"] = "expired_token"
        mockCredentialStorage.storage["refreshToken"] = "refresh_token"
        mockCredentialStorage.storage["expiry"] = String(Date().addingTimeInterval(-3_600).timeIntervalSince1970)

        Token.getToken(from: mockCredentialStorage) { token in
            expectNil(token)
            getTokenExpectation.fulfill()
        }

        wait(for: [getTokenExpectation, requestExpectation], timeout: 10.0)
    }

    @Test
    func testExpiredTokenRefreshFailsValidation() {
        let refreshExpectation = TestExpectation(description: "mock server called")
        let validateExpectation = TestExpectation(description: "mock server called")
        let getTokenExpectation = TestExpectation(description: "getToken completion")

        MockURLProtocol.newTokenRequestHandler = { url, _ in
            refreshExpectation.fulfill()
            let jsonResponse = [
                "access_token": "atoken12345", "refresh_token": "rtoken67890", "expires_in": 3_600, "created_at": Int(Date().timeIntervalSince1970), "token_type": "Bearer"
            ]
            return (HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!, try JSONSerialization.data(withJSONObject: jsonResponse, options: []))
        }
        MockURLProtocol.tokenValidationRequestHandler = { _, _ in
            validateExpectation.fulfill()
            throw URLError(.networkConnectionLost)
        }

        mockCredentialStorage.storage["accessToken"] = "expired_token"
        mockCredentialStorage.storage["refreshToken"] = "refresh_token"
        mockCredentialStorage.storage["expiry"] = String(Date().addingTimeInterval(-3_600).timeIntervalSince1970)

        Token.getToken(from: mockCredentialStorage) { token in
            expectNil(token)
            getTokenExpectation.fulfill()
        }

        wait(for: [getTokenExpectation, refreshExpectation, validateExpectation], timeout: 10.0)
    }

    @Test
    func testExpiredTokenRefreshFailsValidationWithWrongResponseType() {
        let refreshExpectation = TestExpectation(description: "mock server called for token refresh")
        let validateExpectation = TestExpectation(description: "mock server called for token validation")
        let getTokenExpectation = TestExpectation(description: "getToken completion")

        MockURLProtocol.newTokenRequestHandler = { url, _ in
            refreshExpectation.fulfill()
            let jsonResponse = [
                "access_token": "atoken12345", "refresh_token": "rtoken67890", "expires_in": 3_600, "created_at": Int(Date().timeIntervalSince1970), "token_type": "Bearer"
            ]
            return (HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!, try JSONSerialization.data(withJSONObject: jsonResponse, options: []))
        }
        MockURLProtocol.tokenValidationRequestHandler = { url, _ in
            validateExpectation.fulfill()
            return (URLResponse(url: url, mimeType: nil, expectedContentLength: 0, textEncodingName: nil), Data())
        }

        mockCredentialStorage.storage["accessToken"] = "expired_token"
        mockCredentialStorage.storage["refreshToken"] = "refresh_token"
        mockCredentialStorage.storage["expiry"] = String(Date().addingTimeInterval(-3_600).timeIntervalSince1970)

        Token.getToken(from: mockCredentialStorage) { token in
            expectNil(token)
            getTokenExpectation.fulfill()
        }

        wait(for: [getTokenExpectation, refreshExpectation, validateExpectation], timeout: 10.0)
    }

    @Test
    func testExpiredTokenRefresh() {
        let refreshExpectation = TestExpectation(description: "refresh called"), validateExpectation = TestExpectation(description: "validate called")
        let getTokenExpectation = TestExpectation(description: "getToken completion")

        MockURLProtocol.newTokenRequestHandler = { url, request in
            #if canImport(FoundationNetworking)
            // body seems to be missing?
            #else
            // get JSON from POST request body stream
            let inputData = try Data(reading: request.httpBodyStream!), json = try JSONSerialization.jsonObject(with: inputData, options: []) as? [String: Any]
            expectEqual(json?["grant_type"] as? String, "refresh_token")
            expectEqual(json?["refresh_token"] as? String, "refresh_token_234")
            expectEqual(json?["client_id"] as? String, "4da53ac2b03225bed1550eba8e4611e086c7b905a3855e6ed12ea08c246758fa")
            #endif
            refreshExpectation.fulfill()
            return (HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!, try JSONSerialization.data(withJSONObject: [
                "access_token": "a34324532", "refresh_token": "r432432", "expires_in": 3_600, "created_at": Int(Date().timeIntervalSince1970), "token_type": "Bearer"
            ], options: []))
        }
        MockURLProtocol.tokenValidationRequestHandler = { url, request in
            expectEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer a34324532")
            validateExpectation.fulfill()
            return (HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data())
        }

        mockCredentialStorage.storage["accessToken"] = "expired_token"
        mockCredentialStorage.storage["refreshToken"] = "refresh_token_234"
        mockCredentialStorage.storage["expiry"] = String(Date().addingTimeInterval(-3_600).timeIntervalSince1970)

        Token.getToken(from: mockCredentialStorage) { token in
            expectNotNil(token)
            getTokenExpectation.fulfill()
        }

        wait(for: [getTokenExpectation, refreshExpectation, validateExpectation], timeout: 10.0)

        expectEqual(mockCredentialStorage.read("accessToken"), "a34324532")
        expectEqual(mockCredentialStorage.read("refreshToken"), "r432432")
    }

    @Test
    func testTokenInitMissingParameter() {
        let refreshExpectation = TestExpectation(description: "mock server called")
        let getTokenExpectation = TestExpectation(description: "getToken completion")

        MockURLProtocol.newTokenRequestHandler = { url, _ in
            refreshExpectation.fulfill()
            let jsonResponse = [
                "refresh_token": "rtoken67890", "expires_in": 3_600, "created_at": Int(Date().timeIntervalSince1970), "token_type": "Bearer"
            ]
            return (HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!, try JSONSerialization.data(withJSONObject: jsonResponse, options: []))
        }
        mockCredentialStorage.storage["accessToken"] = "expired_token"
        mockCredentialStorage.storage["refreshToken"] = "refresh_token"
        mockCredentialStorage.storage["expiry"] = String(Date().addingTimeInterval(-3_600).timeIntervalSince1970)

        Token.getToken(from: mockCredentialStorage) { token in
            expectNil(token)
            getTokenExpectation.fulfill()
        }

        wait(for: [getTokenExpectation, refreshExpectation], timeout: 10.0)
    }

    // MARK: - getToken with Username/Password/OTP

    @Test
    func testGetTokenWithUsernamePasswordOTPSuccess() {
        let tokenExpectation = TestExpectation(description: "getToken completion"), mockExpectation = TestExpectation(description: "mock server called")

        MockURLProtocol.newTokenRequestHandler = { url, request in
            expectEqual(request.value(forHTTPHeaderField: "x-wealthsimple-otp"), "123456")
            #if canImport(FoundationNetworking)
            // body seems to be missing?
            #else
            // get JSON from POST request body stream
            let inputData = try Data(reading: request.httpBodyStream!), json = try JSONSerialization.jsonObject(with: inputData, options: []) as? [String: Any]
            expectEqual(json?["username"] as? String, "test@example.com")
            expectEqual(json?["password"] as? String, "password1")
            expectEqual(json?["grant_type"] as? String, "password")
            expectEqual(json?["client_id"] as? String, "4da53ac2b03225bed1550eba8e4611e086c7b905a3855e6ed12ea08c246758fa")
            expectEqual(json?["scope"] as? String, "read")
            #endif
            let jsonResponse = [
                "access_token": "atoken12345", "refresh_token": "rtoken67890", "expires_in": 3_600, "created_at": Int(Date().timeIntervalSince1970), "token_type": "Bearer"
            ]
            mockExpectation.fulfill()
            return (HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!, try JSONSerialization.data(withJSONObject: jsonResponse, options: []))
        }

        Token.getToken(username: "test@example.com", password: "password1", otp: "123456", credentialStorage: mockCredentialStorage) { result in
            if case .success(let token) = result {
                expectNotNil(token)
                // Verify token was saved to credential storage
                expectEqual(self.mockCredentialStorage.read("accessToken"), "atoken12345")
                expectEqual(self.mockCredentialStorage.read("refreshToken"), "rtoken67890")
                expectNotNil(self.mockCredentialStorage.read("expiry"))
                tokenExpectation.fulfill()
            } else {
                recordFailure("Expected success but got error")
            }
        }

        wait(for: [mockExpectation, tokenExpectation], timeout: 10.0)
    }

    @Test
    func testGetTokenWithUsernamePasswordOTPNetworkFailure() {
        let tokenExpectation = TestExpectation(description: "getToken completion")
        let serverExpectation = TestExpectation(description: "mock server called")

        // Set up the mock to throw an error for this test
        MockURLProtocol.newTokenRequestHandler = { _, _ in
            serverExpectation.fulfill()
            throw URLError(.networkConnectionLost)
        }

        Token.getToken(
            username: "test@example.com",
            password: "password",
            otp: "123456",
            credentialStorage: mockCredentialStorage
        ) { result in
            switch result {
            case .success:
                recordFailure("Expected failure due to network error")
            case .failure(let error):
                expectNotNil(error)
            }
            tokenExpectation.fulfill()
        }

        wait(for: [tokenExpectation, serverExpectation], timeout: 10.0)
    }

    @Test
    func testGetTokenWithWrongResponseType() {
        let tokenExpectation = TestExpectation(description: "getToken completion")
        let serverExpectation = TestExpectation(description: "mock server called")

        // Set up the mock to return an URLResponse which is not a HTTPURLResponse for this test
        MockURLProtocol.newTokenRequestHandler = { url, _ in
            serverExpectation.fulfill()
            return (URLResponse(url: url, mimeType: nil, expectedContentLength: 0, textEncodingName: nil), Data())
        }

        Token.getToken(
            username: "test@example.com",
            password: "password",
            otp: "123456",
            credentialStorage: mockCredentialStorage
        ) { result in
            switch result {
            case .success:
                recordFailure("Expected failure due to wrong response type")
            case .failure(let error):
                expectNotNil(error)
            }
            tokenExpectation.fulfill()
        }

        wait(for: [tokenExpectation, serverExpectation], timeout: 10.0)
    }

    @Test
    func testGetTokenWithInvalidJSON() {
        let tokenExpectation = TestExpectation(description: "getToken completion")
        let serverExpectation = TestExpectation(description: "mock server called")

        // Set up the mock to throw return an URLResponse which is not a HTTPURLResponse for this test
        MockURLProtocol.newTokenRequestHandler = { url, _ in
            serverExpectation.fulfill()
            return (HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data("NOT JSON".utf8))
        }

        Token.getToken(
            username: "test@example.com",
            password: "password",
            otp: "123456",
            credentialStorage: mockCredentialStorage
        ) { result in
            switch result {
            case .success:
                recordFailure("Expected failure due to wrong response type")
            case .failure(let error):
                expectNotNil(error)
            }
            tokenExpectation.fulfill()
        }

        wait(for: [tokenExpectation, serverExpectation], timeout: 10.0)
    }

}
