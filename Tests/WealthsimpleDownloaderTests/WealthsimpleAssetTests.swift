@testable import WealthsimpleDownloader
import Testing

@Suite
final class WealthsimpleAssetTests {
    @Test
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

    @Test
    func testInitWithCurrency() {
        let asset = WealthsimpleAsset(currency: "CAD")
        XCTAssertEqual(asset.id, "CAD")
        XCTAssertEqual(asset.symbol, "CAD")
        XCTAssertEqual(asset.currency, "CAD")
        XCTAssertEqual(asset.name, "CAD")
        XCTAssertEqual(asset.type, .currency)
    }

    @Test
    func testInitWithCurrencyDifferentValue() {
        let asset = WealthsimpleAsset(currency: "USD")
        XCTAssertEqual(asset.id, "USD")
        XCTAssertEqual(asset.symbol, "USD")
        XCTAssertEqual(asset.currency, "USD")
        XCTAssertEqual(asset.name, "USD")
        XCTAssertEqual(asset.type, .currency)
    }

    @Test
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

    @Test
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
