@testable import WealthsimpleDownloader
import XCTest

final class WealthsimpleAssetTests: XCTestCase {
    func testInitWithValidJSON() throws {
        let json: [String: Any] = [
            "security_id": "asset-123",
            "symbol": "AAPL",
            "currency": "USD",
            "name": "Apple Inc.",
            "type": "equity"
        ]
        let asset = try WealthsimpleAsset(json: json)
        XCTAssertEqual(asset.id, "asset-123")
        XCTAssertEqual(asset.symbol, "AAPL")
        XCTAssertEqual(asset.currency, "USD")
        XCTAssertEqual(asset.name, "Apple Inc.")
        XCTAssertEqual(asset.type, .equity)
    }

    func testInitWithCurrency() {
        let asset = WealthsimpleAsset(currency: "CAD")
        XCTAssertEqual(asset.id, "CAD")
        XCTAssertEqual(asset.symbol, "CAD")
        XCTAssertEqual(asset.currency, "CAD")
        XCTAssertEqual(asset.name, "CAD")
        XCTAssertEqual(asset.type, .currency)
    }

    func testInitWithCurrencyDifferentValue() {
        let asset = WealthsimpleAsset(currency: "USD")
        XCTAssertEqual(asset.id, "USD")
        XCTAssertEqual(asset.symbol, "USD")
        XCTAssertEqual(asset.currency, "USD")
        XCTAssertEqual(asset.name, "USD")
        XCTAssertEqual(asset.type, .currency)
    }

    func testInitWithMissingParameterThrows() {
        let json: [String: Any] = [
            "security_id": "asset-123",
            "symbol": "AAPL",
            "currency": "USD",
            "name": "Apple Inc."
            // missing "type"
        ]
        assert(
            try WealthsimpleAsset(json: json),
            throws: AssetError.missingResultParamenter(json: "{\"currency\":\"USD\",\"name\":\"Apple Inc.\",\"security_id\":\"asset-123\",\"symbol\":\"AAPL\"}")
        )
    }

    func testInitWithInvalidTypeThrows() {
        let json: [String: Any] = [
            "security_id": "asset-123",
            "symbol": "AAPL",
            "currency": "USD",
            "name": "Apple Inc.",
            "type": "invalid_type"
        ]
        assert(
            try WealthsimpleAsset(json: json),
            throws: AssetError.invalidResultParamenter(
                json: "{\"currency\":\"USD\",\"name\":\"Apple Inc.\",\"security_id\":\"asset-123\",\"symbol\":\"AAPL\",\"type\":\"invalid_type\"}"
            )
        )
    }
}
