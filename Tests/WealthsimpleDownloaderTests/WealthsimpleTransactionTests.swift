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
import Testing
@testable import WealthsimpleDownloader

@Suite
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
        guard let resultToken else {
            Issue.record("Did not get valid token")
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

    private func setupRESTMockForSuccess(transactions: [[String: Any]], expectation: DispatchSemaphore) {
        mockHTTPClient.transactionsRequestHandler = { url, request in
            #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer valid_access_token3")
            #expect(url.query()?.contains("effective_date_start") ?? false)
            #expect(url.query()?.contains("process_date_start") ?? false)

            let jsonResponse = [
                "object": "transaction",
                "results": transactions
            ]
            expectation.signal()
            return (HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                    try JSONSerialization.data(withJSONObject: jsonResponse, options: []))
        }
    }

    private func setupGraphQLMockForSuccess(
        activityResponses: [[String: Any]], fxResponses: [[String: Any]], expectation: DispatchSemaphore
    ) throws {
        var callCount = 0
        mockHTTPClient.graphQLRequestHandler = { _, request in
            callCount += 1
            #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer valid_access_token3")

            guard let url = request.url else {
                Issue.record("Request URL is empty")
                throw TransactionError.httpError(error: "Request URL is empty")
            }
            guard let stream = request.httpBodyStream, let inputData = try? Data(reading: stream), let requestString = String(data: inputData, encoding: .utf8) else {
                Issue.record("Request body is empty")
                throw TransactionError.noDataReceived
            }

            var response = [String: Any]()
            if requestString.contains("query FetchActivityFeedItems") {
                #expect(!callCount.isMultiple(of: 2))
                response = activityResponses[(callCount - 1) / 2]
            } else if requestString.contains("query CreditCardActivity") {
                #expect(callCount.isMultiple(of: 2))
                response = fxResponses[(callCount / 2) - 1]
            } else {
                Issue.record("Unexpected GraphQL query")
            }
            if callCount == activityResponses.count + fxResponses.count {
                expectation.signal()
            } else if callCount > activityResponses.count + fxResponses.count {
                Issue.record("Too many GraphQL calls")
            }

            return (HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!, try JSONSerialization.data(withJSONObject: response, options: []))
        }
    }

    private func testRESTTransactionsFailure(response: (URLResponse, Data), expectedError: TransactionError) throws {

        let mockExpectation = DispatchSemaphore(value: 0)
        try testRESTTransactionsFailure(
            response: { _, _ in
                mockExpectation.signal()
                return response
            },
            expectedError: expectedError
        )

        #expect(mockExpectation.wait(timeout: .now() + 10.0) == .success)
    }

    private func testRESTTransactionsFailure(
        response: @escaping ((URL, URLRequest) throws -> (URLResponse, Data)),
        expectedError: TransactionError
    ) throws {
        let expectation = DispatchSemaphore(value: 0)

        mockHTTPClient.transactionsRequestHandler = response

        WealthsimpleTransaction.getTransactions(token: try createValidToken(), account: createValidAccount(), startDate: Self.startDate, dependencies: dependencies) {
            switch $0 {
            case .success:
                Issue.record("Expected failure")
            case .failure(let error):
                #expect(error == expectedError)
            }
            expectation.signal()
        }

        #expect(expectation.wait(timeout: .now() + 10.0) == .success)
    }

    private func testRESTJSONParsingFailure(jsonData: Data, expectedError: TransactionError) throws {
        try testRESTTransactionsFailure(response: (
                HTTPURLResponse(url: URL(string: "http://test.com")!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                jsonData
            ),
            expectedError: expectedError
        )
    }

    private func testRESTJSONParsingFailure(jsonObject: [String: Any], expectedError: TransactionError) throws {
        guard let jsonData = try? JSONSerialization.data(withJSONObject: jsonObject, options: []) else {
            Issue.record("Failed to create JSON data")
            return
        }
        try testRESTJSONParsingFailure(jsonData: jsonData, expectedError: expectedError)
    }

    private func testGraphQLFailure(
        expectation: DispatchSemaphore,
        expectedError: TransactionError,
        dependencies: DownloaderDependencies? = nil
    ) throws {
        WealthsimpleTransaction.getTransactions(
            token: try createValidToken(),
            account: createGraphQLAccount(),
            startDate: Self.startDate,
            dependencies: dependencies ?? self.dependencies
        ) { result in
            switch result {
            case .success(let transactions):
                Issue.record("Expected failure but got success with transactions: \(transactions)")
            case .failure(let error):
                #expect(error == expectedError)
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
            expectation.signal()
        }
    }

    private func testGraphQLJSONParsingFailure( // swiftlint:disable:next discouraged_optional_collection
        activityResponse: [String: Any], fxResponse: [String: Any]?, expectedError: TransactionError
    ) throws {
        let expectation = DispatchSemaphore(value: 0)
        let mockExpectation = DispatchSemaphore(value: 0)

        let fxResponses = fxResponse != nil ? [fxResponse!] : []
        try setupGraphQLMockForSuccess(activityResponses: [activityResponse], fxResponses: fxResponses, expectation: mockExpectation)
        try testGraphQLFailure(expectation: expectation, expectedError: expectedError)

        #expect(expectation.wait(timeout: .now() + 10.0) == .success)
        #expect(mockExpectation.wait(timeout: .now() + 10.0) == .success)
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

    @Test
    func getTransactionsSuccess() throws { // swiftlint:disable:this function_body_length
        let expectation = DispatchSemaphore(value: 0)
        let mockExpectation = DispatchSemaphore(value: 0)

        let transactionJSON = Self.transactionJSON
        setupRESTMockForSuccess(transactions: [transactionJSON], expectation: mockExpectation)

        WealthsimpleTransaction.getTransactions(token: try createValidToken(), account: createValidAccount(), startDate: Self.startDate, dependencies: dependencies) {
            switch $0 {
            case .success(let transactions):
                #expect(transactions.count == 1)

                let transaction = transactions[0]
                #expect(transaction.id == "transaction-123")
                #expect(transaction.accountId == "account-456")
                #expect(transaction.transactionType == .buy)
                #expect(transaction.description == "Buy AAPL")
                #expect(transaction.symbol == "AAPL")
                #expect(transaction.quantity == "10.0")
                #expect(transaction.marketPriceAmount == "150.00")
                #expect(transaction.marketPriceCurrency == "USD")
                #expect(transaction.marketValueAmount == "1500.00")
                #expect(transaction.marketValueCurrency == "USD")
                #expect(transaction.netCashAmount == "-1500.00")
                #expect(transaction.netCashCurrency == "USD")
                #expect(transaction.fxRate == "1.0")

                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd"
                #expect(transaction.processDate == dateFormatter.date(from: "2023-01-15"))
                #expect(transaction.effectiveDate == dateFormatter.date(from: "2023-01-16"))

            case .failure(let error):
                Issue.record("Expected success but got error: \(error)")
            }
            expectation.signal()
        }

        #expect(expectation.wait(timeout: .now() + 10.0) == .success)
        #expect(mockExpectation.wait(timeout: .now() + 10.0) == .success)
    }

    @Test
    func getTransactionsEmptyResults() throws {
        let expectation = DispatchSemaphore(value: 0)
        let mockExpectation = DispatchSemaphore(value: 0)

        setupRESTMockForSuccess(transactions: [], expectation: mockExpectation)

        WealthsimpleTransaction.getTransactions(token: try createValidToken(), account: createValidAccount(), startDate: Self.startDate, dependencies: dependencies) {
            switch $0 {
            case .success(let transactions):
                #expect(transactions.isEmpty)
            case .failure(let error):
                Issue.record("Expected success but got error: \(error)")
            }
            expectation.signal()
        }

        #expect(expectation.wait(timeout: .now() + 10.0) == .success)
        #expect(mockExpectation.wait(timeout: .now() + 10.0) == .success)
    }

    @Test
    func getTransactionsMultipleTransactionTypes() throws {
        let expectation = DispatchSemaphore(value: 0)
        let mockExpectation = DispatchSemaphore(value: 0)

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

        WealthsimpleTransaction.getTransactions(token: try createValidToken(), account: createValidAccount(), startDate: Self.startDate, dependencies: dependencies) {
            switch $0 {
            case .success(let transactions):
                #expect(transactions.count == 4)
                #expect(transactions[0].transactionType == .buy)
                #expect(transactions[1].transactionType == .dividend)
                #expect(transactions[2].transactionType == .custodianFee)
                #expect(transactions[3].transactionType == .paymentTransferIn)
            case .failure(let error):
                Issue.record("Expected success but got error: \(error)")
            }
            expectation.signal()
        }

        #expect(expectation.wait(timeout: .now() + 10.0) == .success)
        #expect(mockExpectation.wait(timeout: .now() + 10.0) == .success)
    }

    @Test
    func getTransactionsAppendsStartDateQueryItems() throws {
        let startDate = Date(timeIntervalSince1970: 1_700_000_000)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let expectedDateString = dateFormatter.string(from: startDate)

        let expectation = DispatchSemaphore(value: 0)
        let mockExpectation = DispatchSemaphore(value: 0)

        mockHTTPClient.transactionsRequestHandler = { url, request in
            #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer valid_access_token3")
            #expect(url.query()?.contains("effective_date_start=\(expectedDateString)") ?? false)
            #expect(url.query()?.contains("process_date_start=\(expectedDateString)") ?? false)

            let jsonResponse = [
                "object": "transaction",
                "results": [Self.transactionJSON]
            ]
            mockExpectation.signal()
            return (HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                    try JSONSerialization.data(withJSONObject: jsonResponse, options: []))
        }

        WealthsimpleTransaction.getTransactions(token: try createValidToken(), account: createValidAccount(), startDate: startDate, dependencies: dependencies) { result in
            switch result {
            case .success(let transactions):
                #expect(transactions.count == 1)
            case .failure(let error):
                Issue.record("Expected success but got error: \(error)")
            }
            expectation.signal()
        }

        #expect(expectation.wait(timeout: .now() + 10.0) == .success)
        #expect(mockExpectation.wait(timeout: .now() + 10.0) == .success)
    }

    // MARK: - Successful GraphQL Tests

#if canImport(FoundationNetworking)
// see https://github.com/swiftlang/swift-corelibs-foundation/issues/3199
#else
    @Test
    func graphQLTransactionsSuccess() throws { // swiftlint:disable:this function_body_length
        let expectation = DispatchSemaphore(value: 0)
        let mockExpectation = DispatchSemaphore(value: 0)

        let response1 = graphQLResponse(for: Self.graphQLTransactionJSON)
        let response2 = graphQLFxResponse(for: Self.graphQLFxJSON)

        try setupGraphQLMockForSuccess(activityResponses: [response1], fxResponses: [response2], expectation: mockExpectation)

        WealthsimpleTransaction.getTransactions(
            token: try createValidToken(),
            account: createGraphQLAccount(),
            startDate: Self.startDate,
            dependencies: dependencies
        ) { result in
            switch result {
            case .success(let transactions):
                #expect(transactions.count == 1)
                let transaction = transactions[0]

                // Check basic fields
                #expect(transaction.id == "cc-transaction-123")
                #expect(transaction.accountId == "credit-test-account-4321")
                #expect(transaction.description == "Foreign Merchant")
                #expect(transaction.transactionType == .purchase)
                #expect(transaction.symbol == "USD")
                #expect(transaction.quantity == "75.00")
                #expect(transaction.marketPriceAmount == "1.00")
                #expect(transaction.marketPriceCurrency == "CAD")
                #expect(transaction.marketValueAmount == "100.00")
                #expect(transaction.marketValueCurrency == "CAD")
                #expect(transaction.netCashAmount == "-100.00")
                #expect(transaction.netCashCurrency == "CAD")
                #expect(transaction.fxRate == "1.33333")

                // Check dates
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSXXX"
                #expect(transaction.processDate == dateFormatter.date(from: "2023-01-15T10:30:45.123456-05:00"))

                dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss z"
                #expect(transaction.effectiveDate == dateFormatter.date(from: "2023-01-16 15:45:30 EST"))

            case .failure(let error):
                Issue.record("Expected success but got error: \(error)")
            }
            expectation.signal()
        }

        #expect(expectation.wait(timeout: .now() + 10.0) == .success)
        #expect(mockExpectation.wait(timeout: .now() + 10.0) == .success)
    }

    @Test
    func graphQLPaginationSuccess() throws {
        let expectation = DispatchSemaphore(value: 0), mockExpectation = DispatchSemaphore(value: 0)

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

        WealthsimpleTransaction.getTransactions(token: try createValidToken(), account: createGraphQLAccount(), startDate: Self.startDate, dependencies: dependencies) {
            switch $0 {
            case .success(let transactions):
                // Expect two transactions (one from each page)
                #expect(transactions.count == 2)
                #expect(transactions[0].id == "cc-transaction-123")
                #expect(transactions[1].id == "cc-transaction-page2")
            case .failure(let error):
                Issue.record("Expected success but got error: \(error)")
            }
            expectation.signal()
        }

        #expect(expectation.wait(timeout: .now() + 10.0) == .success)
        #expect(mockExpectation.wait(timeout: .now() + 10.0) == .success)
    }

#endif

    // MARK: - Network Error Tests

#if canImport(FoundationNetworking)
    @Test
    func getTransactionsNetworkFailure() throws {
        try testRESTTransactionsFailure(
            response: { _, _ in
                throw URLError(.networkConnectionLost)
            }, expectedError: TransactionError.httpError(error: "The operation could not be completed. (NSURLErrorDomain error -1005.)")
        )
    }
#else
    @Test
    func getTransactionsNetworkFailure() throws {
        try testRESTTransactionsFailure(
            response: { _, _ in
                throw URLError(.networkConnectionLost)
            }, expectedError: TransactionError.httpError(error: "The operation couldn’t be completed. (NSURLErrorDomain error -1005.)")
        )
    }
#endif

    @Test
    func getTransactionsEmptyData() throws {
        try testRESTTransactionsFailure(response: (
                HTTPURLResponse(url: URL(string: "http://test.com")!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                Data()
            ), expectedError: TransactionError.invalidJson(json: Data())
        )
    }

    @Test
    func getTransactionsWrongResponseType() throws {
        try testRESTTransactionsFailure(response: (
            URLResponse(url: URL(string: "http://test.com")!, mimeType: nil, expectedContentLength: 0, textEncodingName: nil),
            Data()
        ), expectedError: TransactionError.httpError(error: "No HTTPURLResponse"))
    }

    @Test
    func getTransactionsHTTPError() throws {
        try testRESTTransactionsFailure(response: (
            HTTPURLResponse(url: URL(string: "http://test.com")!, statusCode: 401, httpVersion: nil, headerFields: nil)!,
            Data()
        ), expectedError: TransactionError.httpError(error: "Status code 401"))
    }

    @Test
    func invalidGraphQLURL() throws {
        let invalidDependencies = DownloaderDependencies(
            httpClient: mockHTTPClient,
            configuration: URLConfiguration(
                baseURL: "http://localhost:8080/v1/",
                graphQLURL: "Not a valid URL:::///"
            )
        )
        let expectation = DispatchSemaphore(value: 0)
        let expectedError = TransactionError.httpError(error: "Invalid URL")
        try testGraphQLFailure(
            expectation: expectation,
            expectedError: expectedError,
            dependencies: invalidDependencies
        )
        #expect(expectation.wait(timeout: .now() + 10.0) == .success)
    }

    @Test
    func graphQLRequestErrorFx() throws {
        let expectation = DispatchSemaphore(value: 0)
        let mockExpectation = DispatchSemaphore(value: 0)
        var callCount = 0
        mockHTTPClient.graphQLRequestHandler = { _, request in
            callCount += 1
            guard let url = request.url else {
                Issue.record("Request URL is empty")

                throw TransactionError.httpError(error: "Request URL is empty")
            }
            if callCount == 1 {
                let response = self.graphQLResponse(for: Self.graphQLTransactionJSON)
                return (HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!, try JSONSerialization.data(withJSONObject: response, options: []))
            }
            if callCount == 2 {
                mockExpectation.signal()
                return (HTTPURLResponse(url: url, statusCode: 401, httpVersion: nil, headerFields: nil)!, Data())
            }
            Issue.record("Too many GraphQL calls")
            throw TransactionError.httpError(error: "Too many GraphQL calls")
        }
        let expectedError = TransactionError.httpError(error: "Status code 401")
        try testGraphQLFailure(expectation: expectation, expectedError: expectedError)
        #expect(expectation.wait(timeout: .now() + 10.0) == .success)
        #expect(mockExpectation.wait(timeout: .now() + 10.0) == .success)
    }

    // MARK: - REST JSON Parsing Error Tests

    @Test
    func getTransactionsInvalidJSON() throws {
        let data = Data("NOT VALID JSON".utf8)
        try testRESTJSONParsingFailure(jsonData: data, expectedError: TransactionError.invalidJson(json: data))
    }

    @Test
    func getTransactionsInvalidJSONType() throws {
        guard let jsonData = try? JSONSerialization.data(withJSONObject: ["not", "a", "dictionary"], options: []) else {
            Issue.record("Failed to create test JSON data")
            return
        }
        try testRESTJSONParsingFailure(jsonData: jsonData, expectedError: TransactionError.invalidJson(json: jsonData))
    }

    @Test
    func getTransactionsMissingResults() throws {
        let json = ["object": "transaction"]
        try testRESTJSONParsingFailure(
            jsonObject: json,
            expectedError: TransactionError.missingResultParameter(json: json)
        )
    }

    @Test
    func getTransactionsInvalidObject() throws {
        let json: [String: Any] = ["object": "not_transaction", "results": []]
        try testRESTJSONParsingFailure(
            jsonObject: json,
            expectedError: TransactionError.invalidResultParameter(json: json)
        )
    }

    @Test
    func transactionMissingId() throws {
        var transaction = Self.transactionJSON
        transaction.removeValue(forKey: "id")
        try testRESTJSONParsingFailure(
            jsonObject: ["object": "transaction", "results": [transaction]],
            expectedError: TransactionError.missingResultParameter(json: transaction)
        )
    }

    @Test
    func transactionMissingProcessDate() throws {
        var transaction = Self.transactionJSON
        transaction.removeValue(forKey: "process_date")
        try testRESTJSONParsingFailure(
            jsonObject: ["object": "transaction", "results": [transaction]],
            expectedError: TransactionError.missingResultParameter(json: transaction)
        )
    }

    @Test
    func transactionMissingEffectiveDate() throws {
        var transaction = Self.transactionJSON
        transaction.removeValue(forKey: "effective_date")
        try testRESTJSONParsingFailure(
            jsonObject: ["object": "transaction", "results": [transaction]],
            expectedError: TransactionError.missingResultParameter(json: transaction)
        )
    }

    @Test
    func transactionInvalidProcessDate() throws {
        var transaction = Self.transactionJSON
        transaction["process_date"] = "invalid-date"
        try testRESTJSONParsingFailure(
            jsonObject: ["object": "transaction", "results": [transaction]],
            expectedError: TransactionError.invalidResultParameter(json: transaction)
        )
    }

    @Test
    func transactionInvalidEffectiveDate() throws {
        var transaction = Self.transactionJSON
        transaction["effective_date"] = "invalid-date"
        try testRESTJSONParsingFailure(
            jsonObject: ["object": "transaction", "results": [transaction]],
            expectedError: TransactionError.invalidResultParameter(json: transaction)
        )
    }

    @Test
    func transactionInvalidType() throws {
        var transaction = Self.transactionJSON
        transaction["type"] = "invalid_transaction_type"
        try testRESTJSONParsingFailure(
            jsonObject: ["object": "transaction", "results": [transaction]],
            expectedError: TransactionError.invalidResultParameter(json: transaction)
        )
    }

    @Test
    func transactionInvalidObject() throws {
        var transaction = Self.transactionJSON
        transaction["object"] = "not_transaction"
        try testRESTJSONParsingFailure(
            jsonObject: ["object": "transaction", "results": [transaction]],
            expectedError: TransactionError.invalidResultParameter(json: transaction)
        )
    }

    // MARK: - GraphQL JSON Parsing Error Tests

    @Test
    func graphQLInvalidJSON() throws {
        let mockExpectation = DispatchSemaphore(value: 0)
        let expectation = DispatchSemaphore(value: 0)

        mockHTTPClient.graphQLRequestHandler = { _, request in
            guard let url = request.url else {
                Issue.record("Request URL is empty")
                throw TransactionError.httpError(error: "Request URL is empty")
            }
            mockExpectation.signal()
            return (HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data("NOT VALID JSON".utf8))
        }

        let error = TransactionError.invalidJson(json: Data("NOT VALID JSON".utf8))
        try testGraphQLFailure(expectation: expectation, expectedError: error)

        #expect(mockExpectation.wait(timeout: .now() + 10.0) == .success)
        #expect(expectation.wait(timeout: .now() + 10.0) == .success)
    }

    @Test
    func graphQLInvalidJSONFx() throws {
        let mockExpectation = DispatchSemaphore(value: 0)
        let expectation = DispatchSemaphore(value: 0)

        var callCount = 0
        mockHTTPClient.graphQLRequestHandler = { _, request in
            callCount += 1
            guard let url = request.url else {
                Issue.record("Request URL is empty")
                throw TransactionError.httpError(error: "Request URL is empty")
            }
            if callCount == 1 {
                let response = self.graphQLResponse(for: Self.graphQLTransactionJSON)
                return (HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!, try JSONSerialization.data(withJSONObject: response, options: []))
            }
            if callCount == 2 {
                mockExpectation.signal()
                return (HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data("NOT VALID JSON".utf8))
            }
            Issue.record("Too many GraphQL calls")
            throw TransactionError.httpError(error: "Too many GraphQL calls")
        }

        let error = TransactionError.invalidJson(json: Data("NOT VALID JSON".utf8))
        try testGraphQLFailure(expectation: expectation, expectedError: error)

        #expect(mockExpectation.wait(timeout: .now() + 10.0) == .success)
        #expect(expectation.wait(timeout: .now() + 10.0) == .success)
    }

#if canImport(FoundationNetworking)
// see https://github.com/swiftlang/swift-corelibs-foundation/issues/3199
#else

    @Test
    func graphQLErrorSecondPage() throws {
        let expectation = DispatchSemaphore(value: 0)
        let mockExpectation = DispatchSemaphore(value: 0)

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

        #expect(expectation.wait(timeout: .now() + 10.0) == .success)
        #expect(mockExpectation.wait(timeout: .now() + 10.0) == .success)
    }

    @Test
    func graphQLWrongInnerStructure() throws {
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

    @Test
    func graphQLMissingPageInfo() throws {
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

    @Test
    func graphQLWrongStructure() throws {
        let response1 = Self.graphQLTransactionJSON
        let error = TransactionError.missingResultParameter(json: (Self.graphQLTransactionJSON))
        try testGraphQLJSONParsingFailure(activityResponse: response1, fxResponse: nil, expectedError: error)
    }

    @Test
    func graphQLWrongStructureFx() throws {
        let response1 = graphQLResponse(for: Self.graphQLTransactionJSON)
        let response2 = Self.graphQLFxJSON
        let error = TransactionError.missingResultParameter(json: Self.graphQLFxJSON)

        try testGraphQLJSONParsingFailure(activityResponse: response1, fxResponse: response2, expectedError: error)
    }

    @Test
    func graphQLWrongStructureFx2() throws {
        let response1 = graphQLResponse(for: Self.graphQLTransactionJSON)
        let response2 = [
            "data": [
                "aa0": Self.graphQLFxJSON
            ]
        ]
        let error = TransactionError.invalidResultParameter(json: response2["data"]!)

        try testGraphQLJSONParsingFailure(activityResponse: response1, fxResponse: response2, expectedError: error)
    }

    @Test
    func graphQLMissingRequiredField() throws {
        var transaction = Self.graphQLTransactionJSON
        transaction.removeValue(forKey: "amount")

        let response1 = graphQLResponse(for: transaction)
        let response2 = graphQLFxResponse(for: Self.graphQLFxJSON)
        let error = TransactionError.missingResultParameter(json: (transaction.merging(Self.graphQLFxJSON) { $1 }))

        try testGraphQLJSONParsingFailure(activityResponse: response1, fxResponse: response2, expectedError: error)
    }

    @Test
    func graphQLMissingRequiredFieldForFx() throws {
        var transaction = Self.graphQLTransactionJSON
        transaction.removeValue(forKey: "externalCanonicalId")

        let response1 = graphQLResponse(for: transaction)
        let error = TransactionError.missingResultParameter(json: transaction)

        try testGraphQLJSONParsingFailure(activityResponse: response1, fxResponse: nil, expectedError: error)
    }

    @Test
    func graphQLInvalidType() throws {
        var transaction = Self.graphQLTransactionJSON
        transaction["subType"] = "fun"

        let response1 = graphQLResponse(for: transaction)
        let response2 = graphQLFxResponse(for: Self.graphQLFxJSON)
        let error = TransactionError.invalidResultParameter(json: (transaction.merging(Self.graphQLFxJSON) { $1 }))

        try testGraphQLJSONParsingFailure(activityResponse: response1, fxResponse: response2, expectedError: error)
    }

    @Test
    func graphQLMissingSettlementDate() throws {
        var transaction = Self.graphQLFxJSON
        transaction.removeValue(forKey: "settledAt")

        let response1 = graphQLResponse(for: Self.graphQLTransactionJSON)
        let response2 = graphQLFxResponse(for: transaction)
        let error = TransactionError.missingResultParameter(json: (transaction.merging(Self.graphQLTransactionJSON) { $1 }))

        try testGraphQLJSONParsingFailure(activityResponse: response1, fxResponse: response2, expectedError: error)
    }

    @Test
    func graphQLInvalidDate() throws {
        var transaction = Self.graphQLFxJSON
        transaction["settledAt"] = "invalid-date"

        let response1 = graphQLResponse(for: Self.graphQLTransactionJSON)
        let response2 = graphQLFxResponse(for: transaction)
        let error = TransactionError.invalidResultParameter(json: (transaction.merging(Self.graphQLTransactionJSON) { $1 }))

        try testGraphQLJSONParsingFailure(activityResponse: response1, fxResponse: response2, expectedError: error)
    }

    @Test
    func graphQLMissingFxRate() throws {
        var transaction = Self.graphQLFxJSON
        transaction.removeValue(forKey: "foreignExchangeRate")

        let response1 = graphQLResponse(for: Self.graphQLTransactionJSON)
        let response2 = graphQLFxResponse(for: transaction)
        let error = TransactionError.missingResultParameter(json: (transaction.merging(Self.graphQLTransactionJSON) { $1 }))

        try testGraphQLJSONParsingFailure(activityResponse: response1, fxResponse: response2, expectedError: error)
    }

#endif

}
