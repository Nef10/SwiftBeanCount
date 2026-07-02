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

@Suite(.serialized)
final class CreditCardPositionTests: DownloaderTestCase {

    private static let creditCardAccount = MockAccount(
        id: "ca-credit-card-abc123",
        accountType: .creditCard,
        currency: "CAD",
        number: "99999"
    )

    // MARK: - Helper Methods

    private func createValidToken() throws -> Token {
        let expectation = TestExpectation(description: "createValidToken completion")
        var resultToken: Token?

        MockURLProtocol.tokenValidationRequestHandler = { url, _ in
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        mockCredentialStorage.storage["accessToken"] = "valid_access_token3"
        mockCredentialStorage.storage["refreshToken"] = "valid_refresh_token"
        mockCredentialStorage.storage["expiry"] = String(Date().addingTimeInterval(3_600).timeIntervalSince1970)

        Token.getToken(from: mockCredentialStorage) { token in
            resultToken = token
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 10.0)
        return try requireUnwrap(resultToken)
    }

    private func setupMockForSuccess(balance: String, expectation: TestExpectation) {
        MockURLProtocol.graphQLRequestHandler = { url, request in
            expectEqual(request.httpMethod, "POST")
            expectEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer valid_access_token3")
            expectEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
            expectation.fulfill()
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
        expectEqual(position.accountId, Self.creditCardAccount.id)
        expectEqual(position.quantity, balance)
        expectEqual(position.priceAmount, "1")
        expectEqual(position.priceCurrency, "CAD")
        expectEqual(position.asset.symbol, "CAD")
        expectEqual(position.asset.name, "CAD")
        expectEqual(position.asset.currency, "CAD")
        expectEqual(position.asset.type, .currency)
    }

    private func testCreditCardFailure(
        handler: @escaping (URL, URLRequest) throws -> (URLResponse, Data),
        validate: @escaping (PositionError) -> Void,
        file: StaticString = #file,
        line: UInt = #line
    ) throws {
        let expectation = TestExpectation(description: "getPositions completion")
        MockURLProtocol.graphQLRequestHandler = handler
        WealthsimplePosition.getPositions(token: try createValidToken(), account: Self.creditCardAccount, date: nil) { result in
            switch result {
            case .success:
                recordFailure("Expected failure", file: file, line: line)
            case .failure(let error):
                validate(error)
            }
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 10.0)
    }

    // MARK: - Successful Tests

    @Test
    func testGetCreditCardPositionSuccess() throws {
        let expectation = TestExpectation(description: "getPositions completion")
        let mockExpectation = TestExpectation(description: "mock GraphQL server called")

        setupMockForSuccess(balance: "1234.56", expectation: mockExpectation)

        WealthsimplePosition.getPositions(token: try createValidToken(), account: Self.creditCardAccount, date: nil) { result in
            switch result {
            case .success(let positions):
                expectEqual(positions.count, 1)
                self.assertCreditCardPosition(positions[0], balance: "-1234.56")
            case .failure(let error):
                recordFailure("Expected success but got error: \(error)")
            }
            expectation.fulfill()
        }

        wait(for: [expectation, mockExpectation], timeout: 10.0)
    }

    @Test
    func testGetCreditCardPositionVerifiesRequestBody() throws {
        let expectation = TestExpectation(description: "getPositions completion")
        let mockExpectation = TestExpectation(description: "mock GraphQL server called")

        MockURLProtocol.graphQLRequestHandler = { url, request in
            #if canImport(FoundationNetworking)
            // body seems to be missing?
            #else
            let inputData = try Data(reading: request.httpBodyStream!)
            let json = try JSONSerialization.jsonObject(with: inputData, options: []) as? [String: Any]
            expectEqual(json?["operationName"] as? String, "FetchCreditCardAccountSummary")
            let variables = json?["variables"] as? [String: Any]
            expectEqual(variables?["id"] as? String, Self.creditCardAccount.id)
            expectNotNil(json?["query"] as? String)
            #endif
            mockExpectation.fulfill()
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

        WealthsimplePosition.getPositions(token: try createValidToken(), account: Self.creditCardAccount, date: nil) { _ in
            expectation.fulfill()
        }

        wait(for: [expectation, mockExpectation], timeout: 10.0)
    }

    // MARK: - Failure Tests

    @Test
    func testGetCreditCardPositionNetworkError() throws {
        try testCreditCardFailure(
            handler: { _, _ in throw URLError(.networkConnectionLost) },
            validate: {
                guard case .httpError = $0 else {
                    return recordFailure("Expected httpError but got \($0)")
                }
            }
        )
    }

    @Test
    func testGetCreditCardPositionHTTPError() throws {
        try testCreditCardFailure(
            handler: { url, _ in
                (HTTPURLResponse(url: url, statusCode: 500, httpVersion: nil, headerFields: nil)!, Data())
            },
            validate: { expectEqual($0, PositionError.httpError(error: "Status code 500")) }
        )
    }

    @Test
    func testGetCreditCardPositionWrongResponseType() throws {
        try testCreditCardFailure(
            handler: { url, _ in
                (URLResponse(url: url, mimeType: nil, expectedContentLength: 0, textEncodingName: nil), Data("test".utf8))
            },
            validate: { expectEqual($0, PositionError.httpError(error: "No HTTPURLResponse")) }
        )
    }

    @Test
    func testGetCreditCardPositionInvalidJSON() throws {
        let data = Data("NOT VALID JSON".utf8)
        try testCreditCardFailure(
            handler: { url, _ in
                (HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!, data)
            },
            validate: { expectEqual($0, PositionError.invalidJson(json: data)) }
        )
    }

    @Test
    func testGetCreditCardPositionMissingData() throws {
        try testCreditCardFailure(
            handler: { url, _ in
                let responseJSON: [String: Any] = ["errors": []]
                return (HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                        try JSONSerialization.data(withJSONObject: responseJSON, options: []))
            },
            validate: {
                guard case .missingResultParamenter = $0 else {
                    return recordFailure("Expected missingResultParamenter but got \($0)")
                }
            }
        )
    }

    @Test
    func testGetCreditCardPositionDate() throws {
        let expectation = TestExpectation(description: "getPositions completion")

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let testDate = dateFormatter.date(from: "2023-12-01")!

        WealthsimplePosition.getPositions(token: try createValidToken(), account: Self.creditCardAccount, date: testDate) { result in
            switch result {
            case .success:
                return recordFailure("Expected failure")
            case .failure(let error):
                expectEqual(error, PositionError.invalidRequestParameter(error: "Date parameter is not supported for credit card accounts"))
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 10.0)
    }

    @Test
    func testGetCreditCardPositionMissingBalance() throws {
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
                    return recordFailure("Expected missingResultParamenter but got \($0)")
                }
            }
        )
    }

    @Test
    func testGetCreditCardPositionEmptyData() throws {
        try testCreditCardFailure(
            handler: { url, _ in
                (HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data())
            },
            validate: { expectEqual($0, PositionError.invalidJson(json: Data())) }
        )
    }

}
