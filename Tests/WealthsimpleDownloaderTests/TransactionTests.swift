//
//
//  TransactionTests.swift
//
//
//  Created by Steffen Kötte on 2025-11-09.
//

import Foundation
import Testing
@testable import WealthsimpleDownloader

@Suite(.serialized)
final class TransactionTests {

    @Test
    func testTransactionErrorEqualitySimpleCases() {
        // Test .noDataReceived
        expectEqual(TransactionError.noDataReceived, TransactionError.noDataReceived)
        expectNotEqual(TransactionError.noDataReceived, TransactionError.invalidParameter)

        // Test .httpError
        expectEqual(TransactionError.httpError(error: "test"), TransactionError.httpError(error: "test"))
        expectNotEqual(TransactionError.httpError(error: "test"), TransactionError.httpError(error: "different"))
        expectNotEqual(TransactionError.httpError(error: "test"), TransactionError.noDataReceived)

        // Test .invalidJson
        let data1 = Data("test1".utf8)
        let data2 = Data("test2".utf8)
        expectEqual(TransactionError.invalidJson(json: data1), TransactionError.invalidJson(json: data1))
        expectNotEqual(TransactionError.invalidJson(json: data1), TransactionError.invalidJson(json: data2))
        expectNotEqual(TransactionError.invalidJson(json: data1), TransactionError.noDataReceived)
    }

    @Test
    func testTransactionErrorEqualityJSONParameters() {
        let json1 = ["key": "value" as Any]
        let json2 = ["key": "other" as Any]

        // Test .missingResultParameter
        expectEqual(TransactionError.missingResultParameter(json: json1), TransactionError.missingResultParameter(json: json1))
        expectNotEqual(TransactionError.missingResultParameter(json: json1), TransactionError.missingResultParameter(json: json2))
        expectNotEqual(TransactionError.missingResultParameter(json: json1), TransactionError.noDataReceived)

        // Test .invalidResultParameter
        expectEqual(TransactionError.invalidResultParameter(json: json1), TransactionError.invalidResultParameter(json: json1))
        expectNotEqual(TransactionError.invalidResultParameter(json: json1), TransactionError.invalidResultParameter(json: json2))
        expectNotEqual(TransactionError.invalidResultParameter(json: json1), TransactionError.noDataReceived)
    }

    @Test
    func testTransactionErrorEqualityTokenAndOthers() {
        // Test .tokenError
        expectEqual(TransactionError.tokenError(.noToken), TransactionError.tokenError(.noToken))
        expectNotEqual(
            TransactionError.tokenError(.noToken),
            TransactionError.tokenError(.invalidJson(error: "test"))
        )
        expectNotEqual(TransactionError.tokenError(.noToken), TransactionError.noDataReceived)

        // Test .invalidParameter
        expectEqual(TransactionError.invalidParameter, TransactionError.invalidParameter)
        expectNotEqual(TransactionError.invalidParameter, TransactionError.noDataReceived)
    }

    @Test
    func testTransactionErrorEqualityInvalidJSON() {
        let invalidJson: [String: Any] = ["invalid": NSObject()]
        expectNotEqual(
            TransactionError.missingResultParameter(json: invalidJson),
            TransactionError.missingResultParameter(json: invalidJson)
        )
        expectNotEqual(
            TransactionError.invalidResultParameter(json: invalidJson),
            TransactionError.invalidResultParameter(json: invalidJson)
        )
    }

    @Test
    func testTransactionErrorLocalizedDescription() {
        expectEqual(TransactionError.noDataReceived.errorDescription, "No Data was received from the server")
        expectEqual(TransactionError.httpError(error: "Test HTTP Error").errorDescription, "An HTTP error occurred: Test HTTP Error")
        let invalidJsonData = Data("invalid".utf8)
        expectEqual(TransactionError.invalidJson(json: invalidJsonData).errorDescription, "The server response contained invalid JSON: \(invalidJsonData)")
        let missingJson = ["missing": true as Any]
        expectNoThrow(try {
            let missingJsonStr = try String(data: JSONSerialization.data(withJSONObject: missingJson), encoding: .utf8)!
            expectEqual(
                TransactionError.missingResultParameter(json: missingJson).errorDescription,
                "The server response JSON was missing expected parameters: \(missingJsonStr)"
            )
            let invalidJson = ["invalid": true as Any]
            let invalidJsonStr = try String(data: JSONSerialization.data(withJSONObject: invalidJson), encoding: .utf8)!
            expectEqual(
                TransactionError.invalidResultParameter(json: invalidJson).errorDescription,
                "The server response JSON contained invalid parameters: \(invalidJsonStr)"
            )
        }())
        let tokenError = TokenError.noToken
        expectEqual(TransactionError.tokenError(tokenError).errorDescription, tokenError.localizedDescription)
        expectEqual(TransactionError.invalidParameter.errorDescription, "Invalid paramter passed in")
    }

}
