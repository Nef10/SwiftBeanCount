import Testing
@testable import WealthsimpleDownloader

@Suite(.serialized)
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
        expectEqual(asset.id, "asset-123")
        expectEqual(asset.symbol, "AAPL")
        expectEqual(asset.currency, "USD")
        expectEqual(asset.name, "Apple Inc.")
        expectEqual(asset.type, .equity)
    }

    @Test
    func testInitWithCurrency() {
        let asset = WealthsimpleAsset(currency: "CAD")
        expectEqual(asset.id, "CAD")
        expectEqual(asset.symbol, "CAD")
        expectEqual(asset.currency, "CAD")
        expectEqual(asset.name, "CAD")
        expectEqual(asset.type, .currency)
    }

    @Test
    func testInitWithCurrencyDifferentValue() {
        let asset = WealthsimpleAsset(currency: "USD")
        expectEqual(asset.id, "USD")
        expectEqual(asset.symbol, "USD")
        expectEqual(asset.currency, "USD")
        expectEqual(asset.name, "USD")
        expectEqual(asset.type, .currency)
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
