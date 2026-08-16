//
//  CreditCardPositionTests.swift
//
//
//  Created by Steffen Kötte on 2026-02-08.
//

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Testing
@testable import WealthsimpleDownloader

@Suite
final class CreditCardPositionTests: DownloaderTestCase {

    private static let creditCardAccount = MockAccount(
        id: "ca-credit-card-abc123",
        accountType: .creditCard,
        currency: "CAD",
        number: "99999"
    )

    // MARK: - Helper Methods

    private func createValidToken() throws -> Token {
        let expectation = DispatchSemaphore(value: 0)
        var resultToken: Token?

        mockHTTPClient.tokenValidationRequestHandler = { url, _ in
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        mockCredentialStorage.storage["accessToken"] = "valid_access_token3"
        mockCredentialStorage.storage["refreshToken"] = "valid_refresh_token"
        mockCredentialStorage.storage["expiry"] = String(Date().addingTimeInterval(3_600).timeIntervalSince1970)

        Token.getToken(from: mockCredentialStorage, dependencies: dependencies) { token in
            resultToken = token
            expectation.signal()
        }

        #expect(expectation.wait(timeout: .now() + 10.0) == .success)
        return try #require(resultToken)
    }

    private func setupMockForSuccess(balance: String, expectation: DispatchSemaphore) {
        mockHTTPClient.graphQLRequestHandler = { url, request in
            #expect(request.httpMethod == "POST")
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer valid_access_token3")
            #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
            expectation.signal()
            let responseJSON: [String: Any] = [
                "data": [
                    "creditCardAccount": [
                        "id": Self.creditCardAccount.id,
                        "balance": ["current": balance, "__typename": "Balance"],
                        "__typename": "CreditCardAccount"
                    ]
                ]
            ]
            return (HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                    try JSONSerialization.data(withJSONObject: responseJSON, options: []))
        }
    }

    private func assertCreditCardPosition(_ position: Position, balance: String) {
        #expect(position.accountId == Self.creditCardAccount.id)
        #expect(position.quantity == balance)
        #expect(position.priceAmount == "1")
        #expect(position.priceCurrency == "CAD")
        #expect(position.asset.symbol == "CAD")
        #expect(position.asset.name == "CAD")
        #expect(position.asset.currency == "CAD")
        #expect(position.asset.type == .currency)
    }

    private func testCreditCardFailure(
        handler: @escaping (URL, URLRequest) throws -> (URLResponse, Data),
        validate: @escaping (PositionError) -> Void
    ) throws {
        let expectation = DispatchSemaphore(value: 0)
        mockHTTPClient.graphQLRequestHandler = handler
        WealthsimplePosition.getPositions(token: try createValidToken(), account: Self.creditCardAccount, date: nil, dependencies: dependencies) { result in
            switch result {
            case .success:
                Issue.record("Expected failure")
            case .failure(let error):
                validate(error)
            }
            expectation.signal()
        }
        #expect(expectation.wait(timeout: .now() + 10.0) == .success)
    }

    // MARK: - Successful Tests

    @Test
    func getCreditCardPositionSuccess() throws {
        let expectation = DispatchSemaphore(value: 0)

        let mockExpectation = DispatchSemaphore(value: 0)
        setupMockForSuccess(balance: "1234.56", expectation: mockExpectation)

        WealthsimplePosition.getPositions(token: try createValidToken(), account: Self.creditCardAccount, date: nil, dependencies: dependencies) { result in
            switch result {
            case .success(let positions):
                #expect(positions.count == 1)
                self.assertCreditCardPosition(positions[0], balance: "-1234.56")
            case .failure(let error):
                Issue.record("Expected success but got error: \(error)")
            }
            expectation.signal()
        }

        #expect(expectation.wait(timeout: .now() + 10.0) == .success)
        #expect(mockExpectation.wait(timeout: .now() + 10.0) == .success)
    }

    @Test
    func getCreditCardPositionVerifiesRequestBody() throws {
        let expectation = DispatchSemaphore(value: 0)

        let mockExpectation = DispatchSemaphore(value: 0)
        mockHTTPClient.graphQLRequestHandler = { url, request in
            #if canImport(FoundationNetworking)
            // body seems to be missing?
            #else
            let inputData = try Data(reading: request.httpBodyStream!)
            let json = try JSONSerialization.jsonObject(with: inputData, options: []) as? [String: Any]
            #expect(json?["operationName"] as? String == "FetchCreditCardAccountSummary")
            let variables = json?["variables"] as? [String: Any]
            #expect(variables?["id"] as? String == Self.creditCardAccount.id)
            #expect(json?["query"] is String)
            #endif
            mockExpectation.signal()
            let creditCardData: [String: Any] = [
                "id": Self.creditCardAccount.id,
                "balance": ["current": "42.00", "__typename": "Balance"],
                "__typename": "CreditCardAccount"
            ]
            let responseJSON: [String: Any] = [
                "data": ["creditCardAccount": creditCardData]
            ]
            return (HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                    try JSONSerialization.data(withJSONObject: responseJSON, options: []))
        }

        WealthsimplePosition.getPositions(token: try createValidToken(), account: Self.creditCardAccount, date: nil, dependencies: dependencies) { _ in
            expectation.signal()
        }

        #expect(expectation.wait(timeout: .now() + 10.0) == .success)
        #expect(mockExpectation.wait(timeout: .now() + 10.0) == .success)
    }

    // MARK: - Failure Tests

    @Test
    func getCreditCardPositionNetworkError() throws {
        try testCreditCardFailure(
            handler: { _, _ in throw URLError(.networkConnectionLost) },
            validate: {
                guard case .httpError = $0 else {
                    Issue.record("Expected httpError but got \($0)")
                    return
                }
            }
        )
    }

    @Test
    func getCreditCardPositionHTTPError() throws {
        try testCreditCardFailure(
            handler: { url, _ in
                (HTTPURLResponse(url: url, statusCode: 500, httpVersion: nil, headerFields: nil)!, Data())
            },
            validate: { #expect($0 == PositionError.httpError(error: "Status code 500")) }
        )
    }

    @Test
    func getCreditCardPositionWrongResponseType() throws {
        try testCreditCardFailure(
            handler: { url, _ in
                (URLResponse(url: url, mimeType: nil, expectedContentLength: 0, textEncodingName: nil), Data("test".utf8))
            },
            validate: { #expect($0 == PositionError.httpError(error: "No HTTPURLResponse")) }
        )
    }

    @Test
    func getCreditCardPositionInvalidJSON() throws {
        let data = Data("NOT VALID JSON".utf8)
        try testCreditCardFailure(
            handler: { url, _ in
                (HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!, data)
            },
            validate: { #expect($0 == PositionError.invalidJson(json: data)) }
        )
    }

    @Test
    func getCreditCardPositionMissingData() throws {
        try testCreditCardFailure(
            handler: { url, _ in
                let responseJSON: [String: Any] = ["errors": []]
                return (HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                        try JSONSerialization.data(withJSONObject: responseJSON, options: []))
            },
            validate: {
                guard case .missingResultParamenter = $0 else {
                    Issue.record("Expected missingResultParamenter but got \($0)")
                    return
                }
            }
        )
    }

    @Test
    func getCreditCardPositionDate() throws {

        let expectation = DispatchSemaphore(value: 0)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let testDate = dateFormatter.date(from: "2023-12-01")!

        WealthsimplePosition.getPositions(token: try createValidToken(), account: Self.creditCardAccount, date: testDate, dependencies: dependencies) { result in
            switch result {
            case .success:
                Issue.record("Expected failure")
                return
            case .failure(let error):
                #expect(error == PositionError.invalidRequestParameter(error: "Date parameter is not supported for credit card accounts"))
            }
            expectation.signal()
        }

        #expect(expectation.wait(timeout: .now() + 10.0) == .success)
    }

    @Test
    func getCreditCardPositionMissingBalance() throws {
        try testCreditCardFailure(
            handler: { url, _ in
                let responseJSON: [String: Any] = [
                    "data": [
                        "creditCardAccount": ["id": Self.creditCardAccount.id, "__typename": "CreditCardAccount"]
                    ]
                ]
                return (HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                        try JSONSerialization.data(withJSONObject: responseJSON, options: []))
            },
            validate: {
                guard case .missingResultParamenter = $0 else {
                    Issue.record("Expected missingResultParamenter but got \($0)")
                    return
                }
            }
        )
    }

    @Test
    func getCreditCardPositionEmptyData() throws {
        try testCreditCardFailure(
            handler: { url, _ in
                (HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data())
            },
            validate: { #expect($0 == PositionError.invalidJson(json: Data())) }
        )
    }

}
