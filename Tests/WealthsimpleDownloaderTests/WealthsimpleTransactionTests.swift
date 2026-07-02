// swiftlint:disable file_length
//
//  WealthsimpleTransactionTests.swift
//
//
//  Created by Steffen Kötte on 2025-09-02.
//

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import WealthsimpleDownloader
import XCTest

final class WealthsimpleTransactionTests: DownloaderTestCase { // swiftlint:disable:this type_body_length

    private struct TestAccount: Account {
        let id: String
        let accountType: AccountType
        let currency: String
        let number: String
    }

    private struct PaginationResponses {
        let first: [String: Any]
        let second: [String: Any]
    }

    private static let startDate = Date(timeIntervalSince1970: 0)

    private static let transactionJSON: [String: Any] = [
        "id": "transaction-123",
        "account_id": "account-456",
        "type": "buy",
        "description": "Buy AAPL",
        "symbol": "AAPL",
        "quantity": "10.0",
        "market_price": ["amount": "150.00", "currency": "USD"],
        "market_value": ["amount": "1500.00", "currency": "USD"],
        "net_cash": ["amount": "-1500.00", "currency": "USD"],
        "process_date": "2023-01-15",
        "effective_date": "2023-01-16",
        "fx_rate": "1.0",
        "object": "transaction"
    ]

    private static let graphQLTransactionJSON: [String: Any] = [
        "amount": "100.00",
        "amountSign": "negative",
        "currency": "CAD",
        "externalCanonicalId": "cc-transaction-123",
        "occurredAt": "2023-01-15T10:30:45.123456-05:00",
        "status": "settled",
        "subType": "PURCHASE",
        "spendMerchant": "Foreign Merchant",
        "accountId": "credit-test-account-4321"
    ]

    private static let graphQLFxJSON: [String: Any] = [
        "originalAmount": "75.00",
        "isForeign": true,
        "originalCurrency": "USD",
        "settledAt": "2023-01-16 15:45:30 EST",
        "foreignExchangeRate": "1.33333"
    ]

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
        guard let resultToken else {
            XCTFail("Did not get valid token")
            throw TokenError.noToken
        }
        return resultToken
    }

    private func createValidAccount() -> Account {
        TestAccount(id: "test-account-123", accountType: .tfsa, currency: "CAD", number: "12345")
    }

    private func createGraphQLAccount() -> Account {
        TestAccount(id: "credit-test-account-4321", accountType: .creditCard, currency: "CAD", number: "4321")
    }

    private func setupRESTMockForSuccess(transactions: [[String: Any]], expectation: XCTestExpectation) {
        MockURLProtocol.transactionsRequestHandler = { url, request in
            XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer valid_access_token3")
            XCTAssertTrue(url.query()?.contains("effective_date_start") ?? false)
            XCTAssertTrue(url.query()?.contains("process_date_start") ?? false)

            let jsonResponse = [
                "object": "transaction",
                "results": transactions
            ]
            expectation.fulfill()
            return (HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                    try JSONSerialization.data(withJSONObject: jsonResponse, options: []))
        }
    }

    private func setupGraphQLMockForSuccess(
        activityResponses: [[String: Any]], fxResponses: [[String: Any]], expectation: XCTestExpectation, file: StaticString = #file, line: UInt = #line
    ) throws {
        var callCount = 0
        MockURLProtocol.graphQLRequestHandler = { _, request in
            callCount += 1
            XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json", file: file, line: line)
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer valid_access_token3", file: file, line: line)

            guard let url = request.url else {
                XCTFail("Request URL is empty", file: file, line: line)
                throw TransactionError.httpError(error: "Request URL is empty")
            }
            guard let stream = request.httpBodyStream, let inputData = try? Data(reading: stream), let requestString = String(data: inputData, encoding: .utf8) else {
                XCTFail("Request body is empty", file: file, line: line)
                throw TransactionError.noDataReceived
            }

            var response = [String: Any]()
            if requestString.contains("query FetchActivityFeedItems") {
                XCTAssertEqual(callCount % 2, 1)
                response = activityResponses[(callCount - 1) / 2]
            } else if requestString.contains("query CreditCardActivity") {
                XCTAssertEqual(callCount % 2, 0)
                response = fxResponses[(callCount / 2) - 1]
            } else {
                XCTFail("Unexpected GraphQL query", file: file, line: line)
            }
            if callCount == activityResponses.count + fxResponses.count {
                expectation.fulfill()
            } else if callCount > activityResponses.count + fxResponses.count {
                XCTFail("Too many GraphQL calls", file: file, line: line)
            }

            return (HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!, try JSONSerialization.data(withJSONObject: response, options: []))
        }
    }

    private func testRESTTransactionsFailure(response: (URLResponse, Data), expectedError: TransactionError, file: StaticString = #file, line: UInt = #line) throws {
        let mockExpectation = XCTestExpectation(description: "mock server called")

        try testRESTTransactionsFailure(
            response: { _, _ in
                mockExpectation.fulfill()
                return response
            },
            expectedError: expectedError,
            file: file,
            line: line
        )

        wait(for: [mockExpectation], timeout: 10.0)
    }

    private func testRESTTransactionsFailure(
        response: @escaping ((URL, URLRequest) throws -> (URLResponse, Data)),
        expectedError: TransactionError,
        file: StaticString = #file,
        line: UInt = #line
    ) throws {
        let expectation = XCTestExpectation(description: "getTransactions completion")

        MockURLProtocol.transactionsRequestHandler = response

        WealthsimpleTransaction.getTransactions(token: try createValidToken(), account: createValidAccount(), startDate: Self.startDate) { result in
            switch result {
            case .success:
                XCTFail("Expected failure", file: file, line: line)
            case .failure(let error):
                XCTAssertEqual(error, expectedError, file: file, line: line)
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 10.0)
    }

    private func testRESTJSONParsingFailure(jsonData: Data, expectedError: TransactionError, file: StaticString = #file, line: UInt = #line) throws {
        try testRESTTransactionsFailure(response: (
                HTTPURLResponse(url: URL(string: "http://test.com")!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                jsonData
            ),
            expectedError: expectedError,
            file: file,
            line: line
        )
    }

    private func testRESTJSONParsingFailure(jsonObject: [String: Any], expectedError: TransactionError, file: StaticString = #file, line: UInt = #line) throws {
        guard let jsonData = try? JSONSerialization.data(withJSONObject: jsonObject, options: []) else {
            XCTFail("Failed to create JSON data", file: file, line: line)
            return
        }
        try testRESTJSONParsingFailure(jsonData: jsonData, expectedError: expectedError, file: file, line: line)
    }

    private func testGraphQLFailure(expectation: XCTestExpectation, expectedError: TransactionError, file: StaticString = #file, line: UInt = #line) throws {
        WealthsimpleTransaction.getTransactions(token: try createValidToken(), account: createGraphQLAccount(), startDate: Self.startDate) { result in
            switch result {
            case .success(let transactions):
                XCTFail("Expected failure but got success with transactions: \(transactions)", file: file, line: line)
            case .failure(let error):
                XCTAssertEqual(error, expectedError, file: file, line: line)
                if error != expectedError { // Helper to debug test failures
                    switch error {
                    case .missingResultParameter(let json), .invalidResultParameter(let json):
                        print("Received error JSON:")
                        print(String(data: ((try? JSONSerialization.data(withJSONObject: json, options: [.sortedKeys])) ?? Data()), encoding: .utf8) ?? "")
                    default:
                        break
                    }
                    switch expectedError {
                    case .missingResultParameter(let json), .invalidResultParameter(let json):
                        print(String(data: ((try? JSONSerialization.data(withJSONObject: json, options: [.sortedKeys])) ?? Data()), encoding: .utf8) ?? "")
                        print("Expected error ^ (above)")
                    default:
                        break
                    }
                }
            }
            expectation.fulfill()
        }
    }

    private func testGraphQLJSONParsingFailure( // swiftlint:disable:next discouraged_optional_collection
        activityResponse: [String: Any], fxResponse: [String: Any]?, expectedError: TransactionError, file: StaticString = #file, line: UInt = #line
    ) throws {
        let expectation = XCTestExpectation(description: "getTransactions completion")
        let mockExpectation = XCTestExpectation(description: "mock server called")

        let fxResponses = fxResponse != nil ? [fxResponse!] : []
        try setupGraphQLMockForSuccess(activityResponses: [activityResponse], fxResponses: fxResponses, expectation: mockExpectation)
        try testGraphQLFailure(expectation: expectation, expectedError: expectedError, file: file, line: line)

        wait(for: [expectation, mockExpectation], timeout: 10.0)
    }

    private func graphQLResponse(for transaction: [String: Any]) -> [String: Any] {
        [
            "data": [
                "activityFeedItems": [
                    "edges": [
                        ["node": transaction]
                    ],
                    "pageInfo": [
                        "hasNextPage": false,
                        "endCursor": "cursor123"
                    ]
                ]
            ]
        ]
    }

    private func graphQLFxResponse(for transaction: [String: Any]) -> [String: Any] {
        [
            "data": [
                "a0": transaction
            ]
        ]
    }

    // MARK: - Successful REST Tests

        // swiftlint:disable:next function_body_length
    func testGetTransactionsSuccess() throws {
        let expectation = XCTestExpectation(description: "getTransactions completion")
        let mockExpectation = XCTestExpectation(description: "mock server called")

        let transactionJSON = Self.transactionJSON
        setupRESTMockForSuccess(transactions: [transactionJSON], expectation: mockExpectation)

        WealthsimpleTransaction.getTransactions(token: try createValidToken(), account: createValidAccount(), startDate: Self.startDate) { result in
            switch result {
            case .success(let transactions):
                XCTAssertEqual(transactions.count, 1)

                let transaction = transactions[0]
                XCTAssertEqual(transaction.id, "transaction-123")
                XCTAssertEqual(transaction.accountId, "account-456")
                XCTAssertEqual(transaction.transactionType, .buy)
                XCTAssertEqual(transaction.description, "Buy AAPL")
                XCTAssertEqual(transaction.symbol, "AAPL")
                XCTAssertEqual(transaction.quantity, "10.0")
                XCTAssertEqual(transaction.marketPriceAmount, "150.00")
                XCTAssertEqual(transaction.marketPriceCurrency, "USD")
                XCTAssertEqual(transaction.marketValueAmount, "1500.00")
                XCTAssertEqual(transaction.marketValueCurrency, "USD")
                XCTAssertEqual(transaction.netCashAmount, "-1500.00")
                XCTAssertEqual(transaction.netCashCurrency, "USD")
                XCTAssertEqual(transaction.fxRate, "1.0")

                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd"
                XCTAssertEqual(transaction.processDate, dateFormatter.date(from: "2023-01-15"))
                XCTAssertEqual(transaction.effectiveDate, dateFormatter.date(from: "2023-01-16"))

            case .failure(let error):
                XCTFail("Expected success but got error: \(error)")
            }
            expectation.fulfill()
        }

        wait(for: [expectation, mockExpectation], timeout: 10.0)
    }

    func testGetTransactionsEmptyResults() throws {
        let expectation = XCTestExpectation(description: "getTransactions completion")
        let mockExpectation = XCTestExpectation(description: "mock server called")

        setupRESTMockForSuccess(transactions: [], expectation: mockExpectation)

        WealthsimpleTransaction.getTransactions(token: try createValidToken(), account: createValidAccount(), startDate: Self.startDate) { result in
            switch result {
            case .success(let transactions):
                XCTAssertEqual(transactions.count, 0)
            case .failure(let error):
                XCTFail("Expected success but got error: \(error)")
            }
            expectation.fulfill()
        }

        wait(for: [expectation, mockExpectation], timeout: 10.0)
    }

    func testGetTransactionsMultipleTransactionTypes() throws {
        let expectation = XCTestExpectation(description: "getTransactions completion")
        let mockExpectation = XCTestExpectation(description: "mock server called")

        var buyTransaction = Self.transactionJSON
        buyTransaction["type"] = "buy"
        buyTransaction["id"] = "buy-transaction"

        var dividendTransaction = Self.transactionJSON
        dividendTransaction["type"] = "dividend"
        dividendTransaction["id"] = "dividend-transaction"

        var feeTransaction = Self.transactionJSON
        feeTransaction["type"] = "custodian_fee"
        feeTransaction["id"] = "fee-transaction"

        var paymentTransaction = Self.transactionJSON
        paymentTransaction["type"] = "wealthsimple_payments_transfer_in"
        paymentTransaction["id"] = "payment-transaction"

        setupRESTMockForSuccess(transactions: [buyTransaction, dividendTransaction, feeTransaction, paymentTransaction], expectation: mockExpectation)

        WealthsimpleTransaction.getTransactions(token: try createValidToken(), account: createValidAccount(), startDate: Self.startDate) { result in
            switch result {
            case .success(let transactions):
                XCTAssertEqual(transactions.count, 4)
                XCTAssertEqual(transactions[0].transactionType, .buy)
                XCTAssertEqual(transactions[1].transactionType, .dividend)
                XCTAssertEqual(transactions[2].transactionType, .custodianFee)
                XCTAssertEqual(transactions[3].transactionType, .paymentTransferIn)
            case .failure(let error):
                XCTFail("Expected success but got error: \(error)")
            }
            expectation.fulfill()
        }

        wait(for: [expectation, mockExpectation], timeout: 10.0)
    }

    func testGetTransactionsAppendsStartDateQueryItems() throws {
        let startDate = Date(timeIntervalSince1970: 1_700_000_000)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let expectedDateString = dateFormatter.string(from: startDate)

        let expectation = XCTestExpectation(description: "getTransactions completion")
        let mockExpectation = XCTestExpectation(description: "mock server called")

        MockURLProtocol.transactionsRequestHandler = { url, request in
            XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer valid_access_token3")
            XCTAssert(url.query()?.contains("effective_date_start=\(expectedDateString)") ?? false)
            XCTAssert(url.query()?.contains("process_date_start=\(expectedDateString)") ?? false)

            let jsonResponse = [
                "object": "transaction",
                "results": [Self.transactionJSON]
            ]
            mockExpectation.fulfill()
            return (HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                    try JSONSerialization.data(withJSONObject: jsonResponse, options: []))
        }

        WealthsimpleTransaction.getTransactions(token: try createValidToken(), account: createValidAccount(), startDate: startDate) { result in
            switch result {
            case .success(let transactions):
                XCTAssertEqual(transactions.count, 1)
            case .failure(let error):
                XCTFail("Expected success but got error: \(error)")
            }
            expectation.fulfill()
        }

        wait(for: [expectation, mockExpectation], timeout: 10.0)

    }

    // MARK: - Successful GraphQL Tests

    // swiftlint:disable:next function_body_length
    func testGraphQLTransactionsSuccess() throws {
        let expectation = XCTestExpectation(description: "getTransactions completion")
        let mockExpectation = XCTestExpectation(description: "mock server called")

        let response1 = graphQLResponse(for: Self.graphQLTransactionJSON)
        let response2 = graphQLFxResponse(for: Self.graphQLFxJSON)

        try setupGraphQLMockForSuccess(activityResponses: [response1], fxResponses: [response2], expectation: mockExpectation)

        WealthsimpleTransaction.getTransactions(token: try createValidToken(), account: createGraphQLAccount(), startDate: Self.startDate) { result in
            switch result {
            case .success(let transactions):
                XCTAssertEqual(transactions.count, 1)
                let transaction = transactions[0]

                // Check basic fields
                XCTAssertEqual(transaction.id, "cc-transaction-123")
                XCTAssertEqual(transaction.accountId, "credit-test-account-4321")
                XCTAssertEqual(transaction.description, "Foreign Merchant")
                XCTAssertEqual(transaction.transactionType, .purchase)
                XCTAssertEqual(transaction.symbol, "USD")
                XCTAssertEqual(transaction.quantity, "75.00")
                XCTAssertEqual(transaction.marketPriceAmount, "1.00")
                XCTAssertEqual(transaction.marketPriceCurrency, "CAD")
                XCTAssertEqual(transaction.marketValueAmount, "100.00")
                XCTAssertEqual(transaction.marketValueCurrency, "CAD")
                XCTAssertEqual(transaction.netCashAmount, "-100.00")
                XCTAssertEqual(transaction.netCashCurrency, "CAD")
                XCTAssertEqual(transaction.fxRate, "1.33333")

                // Check dates
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSXXX"
                XCTAssertEqual(transaction.processDate, dateFormatter.date(from: "2023-01-15T10:30:45.123456-05:00"))

                dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss z"
                XCTAssertEqual(transaction.effectiveDate, dateFormatter.date(from: "2023-01-16 15:45:30 EST"))

            case .failure(let error):
                XCTFail("Expected success but got error: \(error)")
            }
            expectation.fulfill()
        }

        wait(for: [expectation, mockExpectation], timeout: 10.0)
    }

    func testGraphQLPaginationSuccess() throws {
        let expectation = XCTestExpectation(description: "getTransactions completion")
        let mockExpectation = XCTestExpectation(description: "mock server called")

        var transaction2 = Self.graphQLTransactionJSON
        transaction2["externalCanonicalId"] = "cc-transaction-page2"

        // First page: hasNextPage = true
        let responsePage1: [String: Any] = [
            "data": [
                "activityFeedItems": [
                    "edges": [["node": Self.graphQLTransactionJSON]],
                    "pageInfo": [
                        "hasNextPage": true,
                        "endCursor": "cursor_page2"
                    ]
                ]
            ]
        ]
        let responsePage2 = graphQLResponse(for: transaction2)

        // FX responses (same for both pages)
        let fxResponse = graphQLFxResponse(for: Self.graphQLFxJSON)

        try setupGraphQLMockForSuccess(activityResponses: [responsePage1, responsePage2], fxResponses: [fxResponse, fxResponse], expectation: mockExpectation)

        WealthsimpleTransaction.getTransactions(token: try createValidToken(), account: createGraphQLAccount(), startDate: Self.startDate) { result in
            switch result {
            case .success(let transactions):
                // Expect two transactions (one from each page)
                XCTAssertEqual(transactions.count, 2)
                XCTAssertEqual(transactions[0].id, "cc-transaction-123")
                XCTAssertEqual(transactions[1].id, "cc-transaction-page2")
            case .failure(let error):
                XCTFail("Expected success but got error: \(error)")
            }
            expectation.fulfill()
        }

        wait(for: [expectation, mockExpectation], timeout: 10.0)
    }

    // MARK: - Network Error Tests

#if canImport(FoundationNetworking)
    func testGetTransactionsNetworkFailure() throws {
        try testRESTTransactionsFailure(
            response: { _, _ in
                throw URLError(.networkConnectionLost)
            }, expectedError: TransactionError.httpError(error: "The operation could not be completed. (NSURLErrorDomain error -1005.)")
        )
    }
#else
    func testGetTransactionsNetworkFailure() throws {
        try testRESTTransactionsFailure(
            response: { _, _ in
                throw URLError(.networkConnectionLost)
            }, expectedError: TransactionError.httpError(error: "The operation couldn’t be completed. (NSURLErrorDomain error -1005.)")
        )
    }
#endif

    func testGetTransactionsEmptyData() throws {
        try testRESTTransactionsFailure(response: (
                HTTPURLResponse(url: URL(string: "http://test.com")!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                Data()
            ), expectedError: TransactionError.invalidJson(json: Data())
        )
    }

    func testGetTransactionsWrongResponseType() throws {
        try testRESTTransactionsFailure(response: (
            URLResponse(url: URL(string: "http://test.com")!, mimeType: nil, expectedContentLength: 0, textEncodingName: nil),
            Data()
        ), expectedError: TransactionError.httpError(error: "No HTTPURLResponse"))
    }

    func testGetTransactionsHTTPError() throws {
        try testRESTTransactionsFailure(response: (
            HTTPURLResponse(url: URL(string: "http://test.com")!, statusCode: 401, httpVersion: nil, headerFields: nil)!,
            Data()
        ), expectedError: TransactionError.httpError(error: "Status code 401"))
    }

    func testInvalidGraphQLURL() throws {
        URLConfiguration.shared.setGraphQLURL("Not a valid URL:::///")
        let expectation = XCTestExpectation(description: "getTransactions completion")
        let expectedError = TransactionError.httpError(error: "Invalid URL")
        try testGraphQLFailure(expectation: expectation, expectedError: expectedError)
        wait(for: [expectation], timeout: 10.0)
    }

    func testInvalidGraphQLURLFx() throws {
        let expectation = XCTestExpectation(description: "getTransactions completion")
        let mockExpectation = XCTestExpectation(description: "mock server called")
        var callCount = 0
        MockURLProtocol.graphQLRequestHandler = { _, request in
            callCount += 1
            guard let url = request.url else {
                XCTFail("Request URL is empty")
                throw TransactionError.httpError(error: "Request URL is empty")
            }
            if callCount == 1 {
                let response = self.graphQLResponse(for: Self.graphQLTransactionJSON)
                URLConfiguration.shared.setGraphQLURL("Not a valid URL:::///")
                mockExpectation.fulfill()
                return (HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!, try JSONSerialization.data(withJSONObject: response, options: []))
            }
            XCTFail("Too many GraphQL calls")
            throw TransactionError.httpError(error: "Too many GraphQL calls")
        }
        let expectedError = TransactionError.httpError(error: "Invalid URL")
        try testGraphQLFailure(expectation: expectation, expectedError: expectedError)
        wait(for: [expectation, mockExpectation], timeout: 10.0)
    }

    func testGraphQLRequestErrorFx() throws {
        let expectation = XCTestExpectation(description: "getTransactions completion")
        let mockExpectation = XCTestExpectation(description: "mock server called")
        var callCount = 0
        MockURLProtocol.graphQLRequestHandler = { _, request in
            callCount += 1
            guard let url = request.url else {
                XCTFail("Request URL is empty")
                throw TransactionError.httpError(error: "Request URL is empty")
            }
            if callCount == 1 {
                let response = self.graphQLResponse(for: Self.graphQLTransactionJSON)
                return (HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!, try JSONSerialization.data(withJSONObject: response, options: []))
            }
            if callCount == 2 {
                mockExpectation.fulfill()
                return (HTTPURLResponse(url: url, statusCode: 401, httpVersion: nil, headerFields: nil)!, Data())
            }
            XCTFail("Too many GraphQL calls")
            throw TransactionError.httpError(error: "Too many GraphQL calls")
        }
        let expectedError = TransactionError.httpError(error: "Status code 401")
        try testGraphQLFailure(expectation: expectation, expectedError: expectedError)
        wait(for: [expectation, mockExpectation], timeout: 10.0)
    }

    // MARK: - REST JSON Parsing Error Tests

    func testGetTransactionsInvalidJSON() throws {
        let data = Data("NOT VALID JSON".utf8)
        try testRESTJSONParsingFailure(jsonData: data, expectedError: TransactionError.invalidJson(json: data))
    }

    func testGetTransactionsInvalidJSONType() throws {
        guard let jsonData = try? JSONSerialization.data(withJSONObject: ["not", "a", "dictionary"], options: []) else {
            XCTFail("Failed to create test JSON data")
            return
        }
        try testRESTJSONParsingFailure(jsonData: jsonData, expectedError: TransactionError.invalidJson(json: jsonData))
    }

    func testGetTransactionsMissingResults() throws {
        let json = ["object": "transaction"]
        try testRESTJSONParsingFailure(
            jsonObject: json,
            expectedError: TransactionError.missingResultParameter(json: json)
        )
    }

    func testGetTransactionsInvalidObject() throws {
        let json: [String: Any] = ["object": "not_transaction", "results": []]
        try testRESTJSONParsingFailure(
            jsonObject: json,
            expectedError: TransactionError.invalidResultParameter(json: json)
        )
    }

    func testTransactionMissingId() throws {
        var transaction = Self.transactionJSON
        transaction.removeValue(forKey: "id")
        try testRESTJSONParsingFailure(
            jsonObject: ["object": "transaction", "results": [transaction]],
            expectedError: TransactionError.missingResultParameter(json: transaction)
        )
    }

    func testTransactionMissingProcessDate() throws {
        var transaction = Self.transactionJSON
        transaction.removeValue(forKey: "process_date")
        try testRESTJSONParsingFailure(
            jsonObject: ["object": "transaction", "results": [transaction]],
            expectedError: TransactionError.missingResultParameter(json: transaction)
        )
    }

    func testTransactionMissingEffectiveDate() throws {
        var transaction = Self.transactionJSON
        transaction.removeValue(forKey: "effective_date")
        try testRESTJSONParsingFailure(
            jsonObject: ["object": "transaction", "results": [transaction]],
            expectedError: TransactionError.missingResultParameter(json: transaction)
        )
    }

    func testTransactionInvalidProcessDate() throws {
        var transaction = Self.transactionJSON
        transaction["process_date"] = "invalid-date"
        try testRESTJSONParsingFailure(
            jsonObject: ["object": "transaction", "results": [transaction]],
            expectedError: TransactionError.invalidResultParameter(json: transaction)
        )
    }

    func testTransactionInvalidEffectiveDate() throws {
        var transaction = Self.transactionJSON
        transaction["effective_date"] = "invalid-date"
        try testRESTJSONParsingFailure(
            jsonObject: ["object": "transaction", "results": [transaction]],
            expectedError: TransactionError.invalidResultParameter(json: transaction)
        )
    }

    func testTransactionInvalidType() throws {
        var transaction = Self.transactionJSON
        transaction["type"] = "invalid_transaction_type"
        try testRESTJSONParsingFailure(
            jsonObject: ["object": "transaction", "results": [transaction]],
            expectedError: TransactionError.invalidResultParameter(json: transaction)
        )
    }

    func testTransactionInvalidObject() throws {
        var transaction = Self.transactionJSON
        transaction["object"] = "not_transaction"
        try testRESTJSONParsingFailure(
            jsonObject: ["object": "transaction", "results": [transaction]],
            expectedError: TransactionError.invalidResultParameter(json: transaction)
        )
    }

    // MARK: - GraphQL JSON Parsing Error Tests

    func testGraphQLInvalidJSON() throws {
        let mockExpectation = XCTestExpectation(description: "mock server called")
        let expectation = XCTestExpectation(description: "getTransactions completion")

        MockURLProtocol.graphQLRequestHandler = { _, request in
            guard let url = request.url else {
                XCTFail("Request URL is empty")
                throw TransactionError.httpError(error: "Request URL is empty")
            }
            mockExpectation.fulfill()
            return (HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data("NOT VALID JSON".utf8))
        }

        let error = TransactionError.invalidJson(json: Data("NOT VALID JSON".utf8))
        try testGraphQLFailure(expectation: expectation, expectedError: error)

        wait(for: [mockExpectation, expectation], timeout: 10.0)
    }

    func testGraphQLInvalidJSONFx() throws {
        let mockExpectation = XCTestExpectation(description: "mock server called")
        let expectation = XCTestExpectation(description: "getTransactions completion")

        var callCount = 0
        MockURLProtocol.graphQLRequestHandler = { _, request in
            callCount += 1
            guard let url = request.url else {
                XCTFail("Request URL is empty")
                throw TransactionError.httpError(error: "Request URL is empty")
            }
            if callCount == 1 {
                let response = self.graphQLResponse(for: Self.graphQLTransactionJSON)
                return (HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!, try JSONSerialization.data(withJSONObject: response, options: []))
            }
            if callCount == 2 {
                mockExpectation.fulfill()
                return (HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data("NOT VALID JSON".utf8))
            }
            XCTFail("Too many GraphQL calls")
            throw TransactionError.httpError(error: "Too many GraphQL calls")
        }

        let error = TransactionError.invalidJson(json: Data("NOT VALID JSON".utf8))
        try testGraphQLFailure(expectation: expectation, expectedError: error)

        wait(for: [mockExpectation, expectation], timeout: 10.0)
    }

    func testGraphQLErrorSecondPage() throws {
        let expectation = XCTestExpectation(description: "getTransactions completion")
        let mockExpectation = XCTestExpectation(description: "mock server called")

        var transaction2 = Self.graphQLTransactionJSON
        transaction2["externalCanonicalId"] = "cc-transaction-page2"

        // First page: hasNextPage = true
        let responsePage1: [String: Any] = [
            "data": [
                "activityFeedItems": [
                    "edges": [["node": Self.graphQLTransactionJSON]],
                    "pageInfo": [
                        "hasNextPage": true,
                        "endCursor": "cursor_page2"
                    ]
                ]
            ]
        ]

        let fxResponse = graphQLFxResponse(for: Self.graphQLFxJSON)
        try setupGraphQLMockForSuccess(activityResponses: [responsePage1, transaction2], fxResponses: [fxResponse], expectation: mockExpectation)

        let expectedError = TransactionError.missingResultParameter(json: transaction2)
        try testGraphQLFailure(expectation: expectation, expectedError: expectedError)

        wait(for: [expectation, mockExpectation], timeout: 10.0)
    }

    func testGraphQLWrongStructure() throws {
        let response1 = Self.graphQLTransactionJSON
        let error = TransactionError.missingResultParameter(json: (Self.graphQLTransactionJSON))
        try testGraphQLJSONParsingFailure(activityResponse: response1, fxResponse: nil, expectedError: error)
    }

    func testGraphQLWrongInnerStructure() throws {
        let response1 = [
            "data": [
                "activityFeedItems": [
                    "edges": [
                        ["node1": Self.graphQLTransactionJSON]
                    ],
                    "pageInfo": [
                        "hasNextPage": false,
                        "endCursor": "cursor123"
                    ]
                ]
            ]
        ]
        let error = TransactionError.invalidResultParameter(json: (["node1": Self.graphQLTransactionJSON]))
        try testGraphQLJSONParsingFailure(activityResponse: response1, fxResponse: nil, expectedError: error)
    }

    func testGraphQLMissingPageInfo() throws {
        let response1 = [
            "data": [
                "activityFeedItems": [
                    "edges": [
                        ["node": Self.graphQLTransactionJSON]
                    ]
                ]
            ]
        ]
        let error = TransactionError.invalidResultParameter(json: ["edges": [["node": Self.graphQLTransactionJSON]]])
        try testGraphQLJSONParsingFailure(activityResponse: response1, fxResponse: nil, expectedError: error)
    }

    func testGraphQLWrongStructureFx() throws {
        let response1 = graphQLResponse(for: Self.graphQLTransactionJSON)
        let response2 = Self.graphQLFxJSON
        let error = TransactionError.missingResultParameter(json: Self.graphQLFxJSON)

        try testGraphQLJSONParsingFailure(activityResponse: response1, fxResponse: response2, expectedError: error)
    }

    func testGraphQLWrongStructureFx2() throws {
        let response1 = graphQLResponse(for: Self.graphQLTransactionJSON)
        let response2 = [
            "data": [
                "aa0": Self.graphQLFxJSON
            ]
        ]
        let error = TransactionError.invalidResultParameter(json: response2["data"]!)

        try testGraphQLJSONParsingFailure(activityResponse: response1, fxResponse: response2, expectedError: error)
    }

    func testGraphQLMissingRequiredField() throws {
        var transaction = Self.graphQLTransactionJSON
        transaction.removeValue(forKey: "amount")

        let response1 = graphQLResponse(for: transaction)
        let response2 = graphQLFxResponse(for: Self.graphQLFxJSON)
        let error = TransactionError.missingResultParameter(json: (transaction.merging(Self.graphQLFxJSON) { $1 }))

        try testGraphQLJSONParsingFailure(activityResponse: response1, fxResponse: response2, expectedError: error)
    }

    func testGraphQLMissingRequiredFieldForFx() throws {
        var transaction = Self.graphQLTransactionJSON
        transaction.removeValue(forKey: "externalCanonicalId")

        let response1 = graphQLResponse(for: transaction)
        let error = TransactionError.missingResultParameter(json: transaction)

        try testGraphQLJSONParsingFailure(activityResponse: response1, fxResponse: nil, expectedError: error)
    }

    func testGraphQLInvalidType() throws {
        var transaction = Self.graphQLTransactionJSON
        transaction["subType"] = "fun"

        let response1 = graphQLResponse(for: transaction)
        let response2 = graphQLFxResponse(for: Self.graphQLFxJSON)
        let error = TransactionError.invalidResultParameter(json: (transaction.merging(Self.graphQLFxJSON) { $1 }))

        try testGraphQLJSONParsingFailure(activityResponse: response1, fxResponse: response2, expectedError: error)
    }

    func testGraphQLMissingSettlementDate() throws {
        var transaction = Self.graphQLFxJSON
        transaction.removeValue(forKey: "settledAt")

        let response1 = graphQLResponse(for: Self.graphQLTransactionJSON)
        let response2 = graphQLFxResponse(for: transaction)
        let error = TransactionError.missingResultParameter(json: (transaction.merging(Self.graphQLTransactionJSON) { $1 }))

        try testGraphQLJSONParsingFailure(activityResponse: response1, fxResponse: response2, expectedError: error)
    }

    func testGraphQLInvalidDate() throws {
        var transaction = Self.graphQLFxJSON
        transaction["settledAt"] = "invalid-date"

        let response1 = graphQLResponse(for: Self.graphQLTransactionJSON)
        let response2 = graphQLFxResponse(for: transaction)
        let error = TransactionError.invalidResultParameter(json: (transaction.merging(Self.graphQLTransactionJSON) { $1 }))

        try testGraphQLJSONParsingFailure(activityResponse: response1, fxResponse: response2, expectedError: error)
    }

    func testGraphQLMissingFxRate() throws {
        var transaction = Self.graphQLFxJSON
        transaction.removeValue(forKey: "foreignExchangeRate")

        let response1 = graphQLResponse(for: Self.graphQLTransactionJSON)
        let response2 = graphQLFxResponse(for: transaction)
        let error = TransactionError.missingResultParameter(json: (transaction.merging(Self.graphQLTransactionJSON) { $1 }))

        try testGraphQLJSONParsingFailure(activityResponse: response1, fxResponse: response2, expectedError: error)
    }

}
