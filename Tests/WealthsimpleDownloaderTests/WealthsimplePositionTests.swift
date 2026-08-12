//
//  WealthsimplePositionTests.swift
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
@Suite(.mockURLProtocolSerialized, .serialized)
final class WealthsimplePositionTests: DownloaderTestCase { // swiftlint:disable:this type_body_length
   private static let mockAccount = MockAccount(id: "account-123", accountType: .tfsa, currency: "CAD", number: "12345-67890")
   private static let positionJSON: [String: Any] = [
       "quantity": "100.0",
       "account_id": "account-123",
       "asset": [
           "security_id": "asset-123",
           "symbol": "AAPL",
           "currency": "USD",
           "name": "Apple Inc.",
           "type": "equity"
       ],
       "market_price": [
           "amount": "150.25",
           "currency": "USD"
       ],
       "position_date": "2023-12-01",
       "object": "position"
   ]
   private static let positionJSON2: [String: Any] = [
       "quantity": "50.0",
       "account_id": "account-123",
       "asset": [
           "security_id": "asset-456",
           "symbol": "GOOGL",
           "currency": "USD",
           "name": "Alphabet Inc.",
           "type": "equity"
       ],
       "market_price": [
           "amount": "120.75",
           "currency": "USD"
       ],
       "position_date": "2023-12-01",
       "object": "position"
   ]
   // MARK: - Helper Methods
   private func createValidToken() throws -> Token {
       let expectation = DispatchSemaphore(value: 0)
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
           expectation.signal()
       }
       #expect(expectation.wait(timeout: .now() + 10.0) == .success)
       return try #require(resultToken)
   }
   private func setupMockForSuccess(positions: [[String: Any]], expectation: DispatchSemaphore) {
       MockURLProtocol.positionsRequestHandler = { url, request in
           #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer valid_access_token3")
           #expect(!((url.query ?? "").contains("date")))
           #expect((url.query ?? "").contains("account_id=\(Self.mockAccount.id)"))
           #expect((url.query ?? "").contains("limit=250"))
           expectation.signal()
           let responseJSON: [String: Any] = ["object": "position", "results": positions]
           return (HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!, try JSONSerialization.data(withJSONObject: responseJSON, options: []))
       }
   }
   private func testPositionsFailure(
       response: @escaping (URL, URLRequest) throws -> (URLResponse, Data),
       expectedError: PositionError,
       file _: StaticString = #file,
       line _: UInt = #line
   ) throws {
       let expectation = DispatchSemaphore(value: 0)
       MockURLProtocol.positionsRequestHandler = response
       WealthsimplePosition.getPositions(token: try createValidToken(), account: Self.mockAccount, date: nil) { result in
           switch result {
           case .success:
               Issue.record("Expected failure")
           case .failure(let error):
               #expect(error == expectedError)
           }
           expectation.signal()
       }
       #expect(expectation.wait(timeout: .now() + 10.0) == .success)
   }
   private func testJSONParsingFailure(
       jsonData: Data,
       expectedError: PositionError,
       file: StaticString = #file,
       line: UInt = #line
   ) throws {
       try testPositionsFailure(
           response: { url, _ in
               (HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!, jsonData)
           },
           expectedError: expectedError,
           file: file,
           line: line
       )
   }
   private func testJSONParsingFailure(
       jsonObject: [String: Any],
       expectedError: PositionError,
       file: StaticString = #file,
       line: UInt = #line
   ) throws {
       guard let jsonData = try? JSONSerialization.data(withJSONObject: jsonObject, options: []) else {
           Issue.record("Failed to create JSON data")
           return
       }
       try testJSONParsingFailure(jsonData: jsonData, expectedError: expectedError, file: file, line: line)
   }
   // MARK: - Successful getPositions Tests
   @Test
   func getPositionsSuccess() throws {
       let expectation = DispatchSemaphore(value: 0)
       let mockExpectation = DispatchSemaphore(value: 0)
       setupMockForSuccess(positions: [Self.positionJSON], expectation: mockExpectation)
       WealthsimplePosition.getPositions(token: try createValidToken(), account: Self.mockAccount, date: nil) { result in
           switch result {
           case .success(let positions):
               #expect(positions.count == 1)
               let position = positions[0]
               #expect(position.accountId == "account-123")
               #expect(position.quantity == "100.0")
               #expect(position.priceAmount == "150.25")
               #expect(position.priceCurrency == "USD")
               #expect(position.asset.symbol == "AAPL")
               #expect(position.asset.name == "Apple Inc.")
               #expect(position.asset.currency == "USD")
               #expect(position.asset.type == .equity)
               let dateFormatter = DateFormatter()
               dateFormatter.dateFormat = "yyyy-MM-dd"
               let expectedDate = dateFormatter.date(from: "2023-12-01")!
               #expect(position.positionDate == expectedDate)
               expectation.signal()
           case .failure(let error):
               Issue.record("Expected success but got error: \(error)")
           }
       }
       #expect(expectation.wait(timeout: .now() + 10.0) == .success)
       #expect(mockExpectation.wait(timeout: .now() + 10.0) == .success)
   }
   @Test
   func getPositionsSuccessWithDate() throws {
       let expectation = DispatchSemaphore(value: 0)
       let mockExpectation = DispatchSemaphore(value: 0)
       MockURLProtocol.positionsRequestHandler = { url, _ in
           // Verify that the date parameter is included in the request
           #expect(url.query?.contains("date=2023-12-01") == true)
           mockExpectation.signal()
           let json = ["object": "position", "results": [Self.positionJSON, Self.positionJSON2]]
           return (HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!, try JSONSerialization.data(withJSONObject: json, options: []))
       }
       let dateFormatter = DateFormatter()
       dateFormatter.dateFormat = "yyyy-MM-dd"
       let testDate = dateFormatter.date(from: "2023-12-01")!
       WealthsimplePosition.getPositions(token: try createValidToken(), account: Self.mockAccount, date: testDate) { result in
           switch result {
           case .success(let positions):
               #expect(positions.count == 2)
               expectation.signal()
           case .failure(let error):
               Issue.record("Expected success but got error: \(error)")
           }
       }
       #expect(expectation.wait(timeout: .now() + 10.0) == .success)
       #expect(mockExpectation.wait(timeout: .now() + 10.0) == .success)
   }
   @Test
   func getPositionsSuccessMultiplePositions() throws {
       let expectation = DispatchSemaphore(value: 0)
       let mockExpectation = DispatchSemaphore(value: 0)
       setupMockForSuccess(positions: [Self.positionJSON, Self.positionJSON2], expectation: mockExpectation)
       WealthsimplePosition.getPositions(token: try createValidToken(), account: Self.mockAccount, date: nil) { result in
           switch result {
           case .success(let positions):
               #expect(positions.count == 2)
               let firstPosition = positions[0]
               #expect(firstPosition.accountId == "account-123")
               #expect(firstPosition.quantity == "100.0")
               #expect(firstPosition.asset.symbol == "AAPL")
               let secondPosition = positions[1]
               #expect(secondPosition.accountId == "account-123")
               #expect(secondPosition.quantity == "50.0")
               #expect(secondPosition.asset.symbol == "GOOGL")
               expectation.signal()
           case .failure(let error):
               Issue.record("Expected success but got error: \(error)")
           }
       }
       #expect(expectation.wait(timeout: .now() + 10.0) == .success)
       #expect(mockExpectation.wait(timeout: .now() + 10.0) == .success)
   }
   // MARK: - Network Failure Tests
#if canImport(FoundationNetworking)
       @Test
       func getPositionsNetworkFailure() throws {
       try testPositionsFailure(
           response: { _, _ in
               throw URLError(.networkConnectionLost)
           }, expectedError: PositionError.httpError(error: "The operation could not be completed. (NSURLErrorDomain error -1005.)")
       )
   }
#else
   @Test
   func getPositionsNetworkFailure() throws {
       try testPositionsFailure(
           response: { _, _ in
               throw URLError(.networkConnectionLost)
           }, expectedError: PositionError.httpError(error: "The operation couldn’t be completed. (NSURLErrorDomain error -1005.)")
       )
   }
#endif
   @Test
   func getPositionsEmptyData() throws {
       try testPositionsFailure(response: { url, _ in
           (HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data())
       }, expectedError: PositionError.invalidJson(json: Data()))
   }
   @Test
   func getPositionsWrongResponseType() throws {
       try testPositionsFailure(response: { url, _ in
           (URLResponse(url: url, mimeType: nil, expectedContentLength: 0, textEncodingName: nil), Data("test".utf8))
       }, expectedError: PositionError.httpError(error: "No HTTPURLResponse"))
   }
   @Test
   func getPositionsHTTPError() throws {
       try testPositionsFailure(response: { url, _ in
           (HTTPURLResponse(url: url, statusCode: 401, httpVersion: nil, headerFields: nil)!, Data())
       }, expectedError: PositionError.httpError(error: "Status code 401"))
   }
   // MARK: - JSON Parsing Error Tests
   @Test
   func getPositionsInvalidJSON() throws {
       let data = Data("NOT VALID JSON".utf8)
       try testJSONParsingFailure(jsonData: data, expectedError: PositionError.invalidJson(json: data))
   }
   @Test
   func getPositionsInvalidJSONType() throws {
       guard let jsonData = try? JSONSerialization.data(withJSONObject: ["not", "a", "dictionary"], options: []) else {
           Issue.record("Failed to create test JSON data")
           return
       }
       try testJSONParsingFailure(
           jsonData: jsonData,
           expectedError: PositionError.invalidJson(json: jsonData)
       )
   }
   @Test
   func getPositionsMissingResults() throws {
       try testJSONParsingFailure(jsonObject: ["object": "position"], expectedError: PositionError.missingResultParamenter(json: "{\"object\":\"position\"}"))
   }
   @Test
   func getPositionsInvalidObject() throws {
       try testJSONParsingFailure(
           jsonObject: ["object": "not_position", "results": []],
           expectedError: PositionError.invalidResultParamenter(json: "{\"object\":\"not_position\",\"results\":[]}")
       )
   }
   @Test
   func getPositionsMissingQuantity() throws {
       var json = Self.positionJSON
       json.removeValue(forKey: "quantity")
       try testJSONParsingFailure(
           jsonObject: ["object": "position", "results": [json]],
           expectedError: PositionError.missingResultParamenter(json:
               String(data: try JSONSerialization.data(withJSONObject: json, options: [.sortedKeys]), encoding: .utf8) ?? ""
           )
       )
   }
   @Test
   func getPositionsWrongObject() throws {
       var json = Self.positionJSON
       json["object"] = "not_position"
       try testJSONParsingFailure(
           jsonObject: ["object": "position", "results": [json]],
           expectedError: PositionError.invalidResultParamenter(json:
               String(data: try JSONSerialization.data(withJSONObject: json, options: [.sortedKeys]), encoding: .utf8) ?? ""
           )
       )
   }
   @Test
   func getPositionsInvalidDate() throws {
       var json = Self.positionJSON
       json["position_date"] = "invalid-date"
       try testJSONParsingFailure(
           jsonObject: ["object": "position", "results": [json]],
           expectedError: PositionError.invalidResultParamenter(json:
               String(data: try JSONSerialization.data(withJSONObject: json, options: [.sortedKeys]), encoding: .utf8) ?? ""
           )
       )
   }
   @Test
   func getPositionsInvalidAsset() throws {
       var json = Self.positionJSON
       json["asset"] = [
           "security_id": "asset-123",
           "symbol": "AAPL",
           "currency": "USD",
           "name": "Apple Inc."
           // missing "type"
       ]
       try testJSONParsingFailure(
           jsonObject: ["object": "position", "results": [json]],
           expectedError: PositionError.assetError(
               AssetError.missingResultParamenter(json:
                   String(data: try JSONSerialization.data(withJSONObject: json["asset"]!, options: [.sortedKeys]), encoding: .utf8) ?? ""
               )
           )
       )
   }
}
