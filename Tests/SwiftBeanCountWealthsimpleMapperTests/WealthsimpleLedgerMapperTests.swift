import SwiftBeanCountModel
@testable import SwiftBeanCountWealthsimpleMapper
import Wealthsimple
import XCTest

struct TestAsset: AssetProvider {
    var symbol = ""
    var type: Asset.AssetType = .currency
}

struct TestPositon: PositionProvider {
    var accountId = ""
    var asset = TestAsset()
    var assetObject: AssetProvider { asset }
    var priceAmount = ""
    var positionDate = Date()
    var priceCurrency = ""
    var quantity = ""
}

final class WealthsimpleLedgerMapperTests: XCTestCase {

    func testMapPositionsErrors() {
        let ledger = Ledger()
        var mapper = WealthsimpleLedgerMapper(ledger: ledger)

        // empty
        let (prices, balances) = try! mapper.mapPositionsToPriceAndBalance([])
        XCTAssert(prices.isEmpty)
        XCTAssert(balances.isEmpty)

        // no account set on mapper
        var position = TestPositon(accountId: "abc123")
        assert(
            try mapper.mapPositionsToPriceAndBalance([position]),
            throws: WealthsimpleConversionError.accountNotFound("abc123")
        )

        // missing commodity
        let account = TestAccount(number: "A1B2C3", id: "abc123")
        mapper.accounts = [account]
        position.priceAmount = "1234"
        position.priceCurrency = "EUR"
        position.asset.symbol = "CAD"
        assert(
            try mapper.mapPositionsToPriceAndBalance([position]),
            throws: WealthsimpleConversionError.missingCommodity("CAD")
        )

        // missing account in ledger
        try! ledger.add(Commodity(symbol: "CAD"))
        mapper = WealthsimpleLedgerMapper(ledger: ledger)
        mapper.accounts = [account]
        position.quantity = "9.871"
        assert(
            try mapper.mapPositionsToPriceAndBalance([position]),
            throws: WealthsimpleConversionError.missingWealthsimpleAccount("A1B2C3")
        )
    }

    func testMapPositions() {
        let ledger = Ledger()
        let name = try! AccountName("Assets:Wealthsimple:Cash")
        try! ledger.add(SwiftBeanCountModel.Account(name: name, metaData: ["importer-type": "wealthsimple", "number": "A1B2C3"]))
        try! ledger.add(Commodity(symbol: "CAD"))
        try! ledger.add(Commodity(symbol: "ETF"))
        var mapper = WealthsimpleLedgerMapper(ledger: ledger)
        let account = TestAccount(number: "A1B2C3", id: "abc123", currency: "CAD")
        mapper.accounts = [account]
        var position = TestPositon(accountId: "abc123", priceAmount: "1234", priceCurrency: "EUR", quantity: "9.871")
        position.asset.symbol = "CAD"

        // currency
        var (prices, balances) = try! mapper.mapPositionsToPriceAndBalance([position])
        var balance = Balance(date: position.positionDate, accountName: name, amount: Amount(number: Decimal(string: "9.871")!, commoditySymbol: "CAD", decimalDigits: 3))
        XCTAssert(prices.isEmpty)
        XCTAssertEqual(balances, [balance])

        // non currency
        position.asset.type = .exchangeTradedFund
        position.asset.symbol = "ETF"
        let price = try! Price(date: position.positionDate, commoditySymbol: "ETF", amount: Amount(number: Decimal(1_234), commoditySymbol: "EUR", decimalDigits: 2))
        balance = Balance(date: position.positionDate,
                          accountName: try! AccountName("Assets:Wealthsimple:ETF"),
                          amount: Amount(number: Decimal(string: "9.871")!, commoditySymbol: "ETF", decimalDigits: 3))
        (prices, balances) = try! mapper.mapPositionsToPriceAndBalance([position])
        XCTAssertEqual(prices, [price])
        XCTAssertEqual(balances, [balance])

        // already exists
        try! ledger.add(price)
        ledger.add(balance)
        mapper = WealthsimpleLedgerMapper(ledger: ledger)
        mapper.accounts = [account]
        (prices, balances) = try! mapper.mapPositionsToPriceAndBalance([position])
        XCTAssert(prices.isEmpty)
        XCTAssert(balances.isEmpty)
    }

}
