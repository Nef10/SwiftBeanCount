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
        let expectation = XCTestExpectation(description: "createValidToken completion")
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
        return try XCTUnwrap(resultToken)
    }

    private func setupMockForSuccess(balance: String, expectation: XCTestExpectation) {
        MockURLProtocol.graphQLRequestHandler = { url, request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer valid_access_token3")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
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
        XCTAssertEqual(position.accountId, Self.creditCardAccount.id)
        XCTAssertEqual(position.quantity, balance)
        XCTAssertEqual(position.priceAmount, "1")
        XCTAssertEqual(position.priceCurrency, "CAD")
        XCTAssertEqual(position.asset.symbol, "CAD")
        XCTAssertEqual(position.asset.name, "CAD")
        XCTAssertEqual(position.asset.currency, "CAD")
        XCTAssertEqual(position.asset.type, .currency)
    }

    private func testCreditCardFailure(
        handler: @escaping (URL, URLRequest) throws -> (URLResponse, Data),
        validate: @escaping (PositionError) -> Void,
        file: StaticString = #file,
        line: UInt = #line
    ) throws {
        let expectation = XCTestExpectation(description: "getPositions completion")
        MockURLProtocol.graphQLRequestHandler = handler
        WealthsimplePosition.getPositions(token: try createValidToken(), account: Self.creditCardAccount, date: nil) { result in
            switch result {
            case .success:
                XCTFail("Expected failure", file: file, line: line)
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
        let expectation = XCTestExpectation(description: "getPositions completion")
        let mockExpectation = XCTestExpectation(description: "mock GraphQL server called")

        setupMockForSuccess(balance: "1234.56", expectation: mockExpectation)

        WealthsimplePosition.getPositions(token: try createValidToken(), account: Self.creditCardAccount, date: nil) { result in
            switch result {
            case .success(let positions):
                XCTAssertEqual(positions.count, 1)
                self.assertCreditCardPosition(positions[0], balance: "-1234.56")
            case .failure(let error):
                XCTFail("Expected success but got error: \(error)")
            }
            expectation.fulfill()
        }

        wait(for: [expectation, mockExpectation], timeout: 10.0)
    }

    @Test
    func testGetCreditCardPositionVerifiesRequestBody() throws {
        let expectation = XCTestExpectation(description: "getPositions completion")
        let mockExpectation = XCTestExpectation(description: "mock GraphQL server called")

        MockURLProtocol.graphQLRequestHandler = { url, request in
            #if canImport(FoundationNetworking)
            // body seems to be missing?
            #else
            let inputData = try Data(reading: request.httpBodyStream!)
            let json = try JSONSerialization.jsonObject(with: inputData, options: []) as? [String: Any]
            XCTAssertEqual(json?["operationName"] as? String, "FetchCreditCardAccountSummary")
            let variables = json?["variables"] as? [String: Any]
            XCTAssertEqual(variables?["id"] as? String, Self.creditCardAccount.id)
            XCTAssertNotNil(json?["query"] as? String)
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
                    return XCTFail("Expected httpError but got \($0)")
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
            validate: { XCTAssertEqual($0, PositionError.httpError(error: "Status code 500")) }
        )
    }

    @Test
    func testGetCreditCardPositionWrongResponseType() throws {
        try testCreditCardFailure(
            handler: { url, _ in
                (URLResponse(url: url, mimeType: nil, expectedContentLength: 0, textEncodingName: nil), Data("test".utf8))
            },
            validate: { XCTAssertEqual($0, PositionError.httpError(error: "No HTTPURLResponse")) }
        )
    }

    @Test
    func testGetCreditCardPositionInvalidJSON() throws {
        let data = Data("NOT VALID JSON".utf8)
        try testCreditCardFailure(
            handler: { url, _ in
                (HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!, data)
            },
            validate: { XCTAssertEqual($0, PositionError.invalidJson(json: data)) }
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
                    return XCTFail("Expected missingResultParamenter but got \($0)")
                }
            }
        )
    }

    @Test
    func testGetCreditCardPositionDate() throws {
        let expectation = XCTestExpectation(description: "getPositions completion")

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let testDate = dateFormatter.date(from: "2023-12-01")!

        WealthsimplePosition.getPositions(token: try createValidToken(), account: Self.creditCardAccount, date: testDate) { result in
            switch result {
            case .success:
                return XCTFail("Expected failure")
            case .failure(let error):
                XCTAssertEqual(error, PositionError.invalidRequestParameter(error: "Date parameter is not supported for credit card accounts"))
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
                    return XCTFail("Expected missingResultParamenter but got \($0)")
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
            validate: { XCTAssertEqual($0, PositionError.invalidJson(json: Data())) }
        )
    }

}
