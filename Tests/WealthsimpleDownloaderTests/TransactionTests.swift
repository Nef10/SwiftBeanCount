//
//
//  TransactionTests.swift
//
//
//  Created by Steffen Kötte on 2025-11-09.
//

import Foundation
@testable import WealthsimpleDownloader
import XCTest

final class TransactionTests: XCTestCase {

    func testTransactionErrorEqualitySimpleCases() {
        // Test .noDataReceived
        XCTAssertEqual(TransactionError.noDataReceived, TransactionError.noDataReceived)
        XCTAssertNotEqual(TransactionError.noDataReceived, TransactionError.invalidParameter)

        // Test .httpError
        XCTAssertEqual(TransactionError.httpError(error: "test"), TransactionError.httpError(error: "test"))
        XCTAssertNotEqual(TransactionError.httpError(error: "test"), TransactionError.httpError(error: "different"))
        XCTAssertNotEqual(TransactionError.httpError(error: "test"), TransactionError.noDataReceived)

        // Test .invalidJson
        let data1 = Data("test1".utf8)
        let data2 = Data("test2".utf8)
        XCTAssertEqual(TransactionError.invalidJson(json: data1), TransactionError.invalidJson(json: data1))
        XCTAssertNotEqual(TransactionError.invalidJson(json: data1), TransactionError.invalidJson(json: data2))
        XCTAssertNotEqual(TransactionError.invalidJson(json: data1), TransactionError.noDataReceived)
    }

    func testTransactionErrorEqualityJSONParameters() {
        let json1 = ["key": "value" as Any]
        let json2 = ["key": "other" as Any]

        // Test .missingResultParameter
        XCTAssertEqual(TransactionError.missingResultParameter(json: json1), TransactionError.missingResultParameter(json: json1))
        XCTAssertNotEqual(TransactionError.missingResultParameter(json: json1), TransactionError.missingResultParameter(json: json2))
        XCTAssertNotEqual(TransactionError.missingResultParameter(json: json1), TransactionError.noDataReceived)

        // Test .invalidResultParameter
        XCTAssertEqual(TransactionError.invalidResultParameter(json: json1), TransactionError.invalidResultParameter(json: json1))
        XCTAssertNotEqual(TransactionError.invalidResultParameter(json: json1), TransactionError.invalidResultParameter(json: json2))
        XCTAssertNotEqual(TransactionError.invalidResultParameter(json: json1), TransactionError.noDataReceived)
    }

    func testTransactionErrorEqualityTokenAndOthers() {
        // Test .tokenError
        XCTAssertEqual(TransactionError.tokenError(.noToken), TransactionError.tokenError(.noToken))
        XCTAssertNotEqual(
            TransactionError.tokenError(.noToken),
            TransactionError.tokenError(.invalidJson(error: "test"))
        )
        XCTAssertNotEqual(TransactionError.tokenError(.noToken), TransactionError.noDataReceived)

        // Test .invalidParameter
        XCTAssertEqual(TransactionError.invalidParameter, TransactionError.invalidParameter)
        XCTAssertNotEqual(TransactionError.invalidParameter, TransactionError.noDataReceived)
    }

    func testTransactionErrorEqualityInvalidJSON() {
        let invalidJson: [String: Any] = ["invalid": NSObject()]
        XCTAssertNotEqual(
            TransactionError.missingResultParameter(json: invalidJson),
            TransactionError.missingResultParameter(json: invalidJson)
        )
        XCTAssertNotEqual(
            TransactionError.invalidResultParameter(json: invalidJson),
            TransactionError.invalidResultParameter(json: invalidJson)
        )
    }

    func testTransactionErrorLocalizedDescription() {
        XCTAssertEqual(TransactionError.noDataReceived.errorDescription, "No Data was received from the server")
        XCTAssertEqual(TransactionError.httpError(error: "Test HTTP Error").errorDescription, "An HTTP error occurred: Test HTTP Error")
        let invalidJsonData = Data("invalid".utf8)
        XCTAssertEqual(TransactionError.invalidJson(json: invalidJsonData).errorDescription, "The server response contained invalid JSON: \(invalidJsonData)")
        let missingJson = ["missing": true as Any]
        XCTAssertNoThrow(try {
            let missingJsonStr = try String(data: JSONSerialization.data(withJSONObject: missingJson), encoding: .utf8)!
            XCTAssertEqual(
                TransactionError.missingResultParameter(json: missingJson).errorDescription,
                "The server response JSON was missing expected parameters: \(missingJsonStr)"
            )
            let invalidJson = ["invalid": true as Any]
            let invalidJsonStr = try String(data: JSONSerialization.data(withJSONObject: invalidJson), encoding: .utf8)!
            XCTAssertEqual(
                TransactionError.invalidResultParameter(json: invalidJson).errorDescription,
                "The server response JSON contained invalid parameters: \(invalidJsonStr)"
            )
        }())
        let tokenError = TokenError.noToken
        XCTAssertEqual(TransactionError.tokenError(tokenError).errorDescription, tokenError.localizedDescription)
        XCTAssertEqual(TransactionError.invalidParameter.errorDescription, "Invalid paramter passed in")
    }

}
