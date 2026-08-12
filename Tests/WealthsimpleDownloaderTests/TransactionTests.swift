//  TransactionTests.swift
//
//
//  Created by Steffen Kötte on 2025-11-09.
//
import Foundation
import Testing
@testable import WealthsimpleDownloader
@Suite
final class TransactionTests {
   @Test
   func transactionErrorEqualitySimpleCases() {
       // Test .noDataReceived
       let noDataReceived = TransactionError.noDataReceived
       #expect(noDataReceived == .noDataReceived)
       #expect(TransactionError.noDataReceived != TransactionError.invalidParameter)
       // Test .httpError
       let httpError = TransactionError.httpError(error: "test")
       #expect(httpError == .httpError(error: "test"))
       #expect(TransactionError.httpError(error: "test") != TransactionError.httpError(error: "different"))
       #expect(TransactionError.httpError(error: "test") != TransactionError.noDataReceived)
       // Test .invalidJson
       let data1 = Data("test1".utf8)
       let data2 = Data("test2".utf8)
       let invalidJson = TransactionError.invalidJson(json: data1)
       #expect(invalidJson == .invalidJson(json: data1))
       #expect(TransactionError.invalidJson(json: data1) != TransactionError.invalidJson(json: data2))
       #expect(TransactionError.invalidJson(json: data1) != TransactionError.noDataReceived)
   }
   @Test
   func transactionErrorEqualityJSONParameters() {
       let json1 = ["key": "value" as Any]
       let json2 = ["key": "other" as Any]
       // Test .missingResultParameter
       let missingResult = TransactionError.missingResultParameter(json: json1)
       #expect(missingResult == .missingResultParameter(json: json1))
       #expect(TransactionError.missingResultParameter(json: json1) != TransactionError.missingResultParameter(json: json2))
       #expect(TransactionError.missingResultParameter(json: json1) != TransactionError.noDataReceived)
       // Test .invalidResultParameter
       let invalidResult = TransactionError.invalidResultParameter(json: json1)
       #expect(invalidResult == .invalidResultParameter(json: json1))
       #expect(TransactionError.invalidResultParameter(json: json1) != TransactionError.invalidResultParameter(json: json2))
       #expect(TransactionError.invalidResultParameter(json: json1) != TransactionError.noDataReceived)
   }
   @Test
   func transactionErrorEqualityTokenAndOthers() {
       // Test .tokenError
       let tokenError = TransactionError.tokenError(.noToken)
       #expect(tokenError == .tokenError(.noToken))
       #expect(TransactionError.tokenError(.noToken) != TransactionError.tokenError(.invalidJson(error: "test")))
       #expect(TransactionError.tokenError(.noToken) != TransactionError.noDataReceived)
       // Test .invalidParameter
       let invalidParameter = TransactionError.invalidParameter
       #expect(invalidParameter == .invalidParameter)
       #expect(TransactionError.invalidParameter != TransactionError.noDataReceived)
   }
   @Test
   func transactionErrorEqualityInvalidJSON() {
       let invalidJson: [String: Any] = ["invalid": NSObject()]
       let missingResult = TransactionError.missingResultParameter(json: invalidJson)
       let invalidResult = TransactionError.invalidResultParameter(json: invalidJson)
       #expect(missingResult != .missingResultParameter(json: invalidJson))
       #expect(invalidResult != .invalidResultParameter(json: invalidJson))
   }
   @Test
   func transactionErrorLocalizedDescription() {
       #expect(TransactionError.noDataReceived.errorDescription == "No Data was received from the server")
       #expect(TransactionError.httpError(error: "Test HTTP Error").errorDescription == "An HTTP error occurred: Test HTTP Error")
       let invalidJsonData = Data("invalid".utf8)
       let expectedDescription = "The server response contained invalid JSON: \(invalidJsonData)"
       #expect(TransactionError.invalidJson(json: invalidJsonData).errorDescription == expectedDescription)
       let missingJson = ["missing": true as Any]
       #expect(throws: Never.self) {
           let missingJsonStr = try String(data: JSONSerialization.data(withJSONObject: missingJson), encoding: .utf8)!
           let expectedMissingDescription = "The server response JSON was missing expected parameters: \(missingJsonStr)"
           #expect(TransactionError.missingResultParameter(json: missingJson).errorDescription == expectedMissingDescription)
           let invalidJson = ["invalid": true as Any]
           let invalidJsonStr = try String(data: JSONSerialization.data(withJSONObject: invalidJson), encoding: .utf8)!
           let expectedInvalidDescription = "The server response JSON contained invalid parameters: \(invalidJsonStr)"
           #expect(TransactionError.invalidResultParameter(json: invalidJson).errorDescription == expectedInvalidDescription)
       }
       let tokenError = TokenError.noToken
       #expect(TransactionError.tokenError(tokenError).errorDescription == tokenError.localizedDescription)
       #expect(TransactionError.invalidParameter.errorDescription == "Invalid paramter passed in")
   }
}
