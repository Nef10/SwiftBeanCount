import Testing
@testable import WealthsimpleDownloader

@Suite
final class WealthsimpleAssetTests {

   @Test
   func initWithValidJSON() throws {
       let json: [String: Any] = [
           "security_id": "asset-123",
           "symbol": "AAPL",
           "currency": "USD",
           "name": "Apple Inc.",
           "type": "equity"
       ]
       let asset = try WealthsimpleAsset(json: json)
       #expect(asset.id == "asset-123")
       #expect(asset.symbol == "AAPL")
       #expect(asset.currency == "USD")
       #expect(asset.name == "Apple Inc.")
       #expect(asset.type == .equity)
   }

   @Test
   func initWithCurrency() {
       let asset = WealthsimpleAsset(currency: "CAD")
       #expect(asset.id == "CAD")
       #expect(asset.symbol == "CAD")
       #expect(asset.currency == "CAD")
       #expect(asset.name == "CAD")
       #expect(asset.type == .currency)
   }

   @Test
   func initWithCurrencyDifferentValue() {
       let asset = WealthsimpleAsset(currency: "USD")
       #expect(asset.id == "USD")
       #expect(asset.symbol == "USD")
       #expect(asset.currency == "USD")
       #expect(asset.name == "USD")
       #expect(asset.type == .currency)
   }

   @Test
   func initWithMissingParameterThrows() {
       let json: [String: Any] = [
           "security_id": "asset-123",
           "symbol": "AAPL",
           "currency": "USD",
           "name": "Apple Inc."
           // missing "type"
       ]
       #expect(throws: AssetError.missingResultParamenter(json: "{\"currency\":\"USD\",\"name\":\"Apple Inc.\",\"security_id\":\"asset-123\",\"symbol\":\"AAPL\"}")) {
           try WealthsimpleAsset(json: json)
       }
   }

   @Test
   func initWithInvalidTypeThrows() {
       let json: [String: Any] = [
           "security_id": "asset-123",
           "symbol": "AAPL",
           "currency": "USD",
           "name": "Apple Inc.",
           "type": "invalid_type"
       ]
       #expect(throws: AssetError.invalidResultParamenter(
               json: "{\"currency\":\"USD\",\"name\":\"Apple Inc.\",\"security_id\":\"asset-123\",\"symbol\":\"AAPL\",\"type\":\"invalid_type\"}"
           )) {
           try WealthsimpleAsset(json: json)
       }
   }
}
