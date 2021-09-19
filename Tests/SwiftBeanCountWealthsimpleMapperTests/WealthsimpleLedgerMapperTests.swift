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

struct TestTransaction: TransactionProvider {
    var id = ""
    var accountId = ""
    var transactionType: Wealthsimple.Transaction.TransactionType = .buy
    var description = ""
    var symbol = ""
    var quantity = ""
    var marketPriceAmount = ""
    var marketPriceCurrency = ""
    var marketValueAmount = ""
    var marketValueCurrency = ""
    var netCashAmount = ""
    var netCashCurrency = ""
    var fxRate = ""
    var effectiveDate = Date()
    var processDate = Date()
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
        var mapper = setupMapper()
        var position = TestPositon(accountId: "abc123", priceAmount: "1234", priceCurrency: "EUR", quantity: "9.871")
        position.asset.symbol = "CAD"

        // currency
        var (prices, balances) = try! mapper.mapPositionsToPriceAndBalance([position])
        var balance = Balance(date: position.positionDate,
                              accountName: try! AccountName("Assets:W:Cash"),
                              amount: Amount(number: Decimal(string: "9.871")!, commoditySymbol: "CAD", decimalDigits: 3))
        XCTAssert(prices.isEmpty)
        XCTAssertEqual(balances, [balance])

        // non currency
        position.asset.type = .exchangeTradedFund
        position.asset.symbol = "ETF"
        let price = try! Price(date: position.positionDate, commoditySymbol: "ETF", amount: Amount(number: Decimal(1_234), commoditySymbol: "EUR", decimalDigits: 2))
        balance = Balance(date: position.positionDate,
                          accountName: try! AccountName("Assets:W:ETF"),
                          amount: Amount(number: Decimal(string: "9.871")!, commoditySymbol: "ETF", decimalDigits: 3))
        (prices, balances) = try! mapper.mapPositionsToPriceAndBalance([position])
        XCTAssertEqual(prices, [price])
        XCTAssertEqual(balances, [balance])

        // already exists
        let ledger = Ledger()
        try! ledger.add(price)
        ledger.add(balance)
        mapper = setupMapper(ledger: ledger)
        (prices, balances) = try! mapper.mapPositionsToPriceAndBalance([position])
        XCTAssert(prices.isEmpty)
        XCTAssert(balances.isEmpty)
    }

    func testMapTransactionsErrors() {
        let ledger = Ledger()
        var mapper = WealthsimpleLedgerMapper(ledger: ledger)

        // empty
        let (prices, transactions) = try! mapper.mapTransactionsToPriceAndTransactions([])
        XCTAssert(prices.isEmpty)
        XCTAssert(transactions.isEmpty)

        // no account set on mapper
        var transaction = TestTransaction(accountId: "abc123")
        assert(
            try mapper.mapTransactionsToPriceAndTransactions([transaction]),
            throws: WealthsimpleConversionError.accountNotFound("abc123")
        )

        // missing account in ledger
        let account = TestAccount(number: "A1B2C3", id: "abc123")
        mapper.accounts = [account]
        transaction.symbol = "CAD"
        transaction.netCashAmount = "7.53"
        assert(
            try mapper.mapTransactionsToPriceAndTransactions([transaction]),
            throws: WealthsimpleConversionError.missingWealthsimpleAccount("A1B2C3")
        )

        // missing commodity
        try! ledger.add(SwiftBeanCountModel.Account(name: try! AccountName("Assets:W:Cash"), metaData: ["importer-type": "wealthsimple", "number": "A1B2C3"]))
        mapper = WealthsimpleLedgerMapper(ledger: ledger)
        mapper.accounts = [account]
        assert(
            try mapper.mapTransactionsToPriceAndTransactions([transaction]),
            throws: WealthsimpleConversionError.missingCommodity("CAD")
        )
    }

    func testMapTransactionsBuy() {
        let mapper = setupMapper()
        var transaction = TestTransaction(id: "id23",
                                          accountId: "abc123",
                                          symbol: "ETF",
                                          quantity: "5.314",
                                          marketPriceAmount: "2.234",
                                          marketPriceCurrency: "CAD",
                                          marketValueCurrency: "CAD",
                                          netCashAmount: "7.53",
                                          netCashCurrency: "CAD")

        var (prices, transactions) = try! mapper.mapTransactionsToPriceAndTransactions([transaction])
        let amount = Amount(number: Decimal(2.234), commoditySymbol: "CAD", decimalDigits: 3)
        var postings = [
            Posting(accountName: try! AccountName("Assets:W:Cash"), amount: Amount(number: Decimal(7.53), commoditySymbol: "CAD", decimalDigits: 2)),
            Posting(accountName: try! AccountName("Assets:W:ETF"),
                    amount: Amount(number: Decimal(5.314), commoditySymbol: "ETF", decimalDigits: 3),
                    cost: try! Cost(amount: amount, date: nil, label: nil))
        ]
        var resultTransaction = Transaction(metaData: TransactionMetaData(date: transaction.processDate, metaData: [MetaDataKeys.id: "id23"]), postings: postings)
        XCTAssertEqual(prices, [try! Price(date: transaction.processDate, commoditySymbol: "ETF", amount: amount)])
        XCTAssertEqual(transactions, [resultTransaction])

        // fx
        transaction.netCashCurrency = "EUR"
        transaction.fxRate = "0.16"
        (prices, transactions) = try! mapper.mapTransactionsToPriceAndTransactions([transaction])
        let priceAmount = Amount(number: Decimal(string: "6.25")!, commoditySymbol: "CAD", decimalDigits: 2)
        postings = [
            Posting(accountName: postings[0].accountName, amount: Amount(number: Decimal(7.53), commoditySymbol: "EUR", decimalDigits: 2), price: priceAmount),
            postings[1]
        ]
        resultTransaction = Transaction(metaData: TransactionMetaData(date: transaction.processDate, metaData: [MetaDataKeys.id: "id23"]), postings: postings)
        XCTAssertEqual(prices, [try! Price(date: transaction.processDate, commoditySymbol: "ETF", amount: amount)])
        XCTAssertEqual(transactions, [resultTransaction])
    }

    private func setupMapper(ledger: Ledger = Ledger()) -> WealthsimpleLedgerMapper {
        try? ledger.add(SwiftBeanCountModel.Account(name: try! AccountName("Assets:W:Cash"), metaData: ["importer-type": "wealthsimple", "number": "A1B2C3"]))
        try? ledger.add(Commodity(symbol: "ETF"))
        try? ledger.add(Commodity(symbol: "CAD"))
        var mapper = WealthsimpleLedgerMapper(ledger: ledger)
        let account = TestAccount(number: "A1B2C3", id: "abc123", currency: "CAD")
        mapper.accounts = [account]
        return mapper
    }

}
