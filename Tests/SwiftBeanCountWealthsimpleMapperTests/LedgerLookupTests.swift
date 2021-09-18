import SwiftBeanCountModel
@testable import SwiftBeanCountWealthsimpleMapper
import Wealthsimple
import XCTest

struct TestAccount: WealthsimpleAccountRepresentable {
    let number: String
    let accountType: Wealthsimple.Account.AccountType
    let currency: String
}

final class LedgerLookupTests: XCTestCase {

    func testLedgerAccountCommoditySymbol() {
        let name1 = try! AccountName("Assets:Test")
        let name2 = try! AccountName("Assets:Test1")
        let symbol = "CAD"
        let ledger = Ledger()
        var ledgerLookup = LedgerLookup(ledger)

        // account does not exist
        XCTAssertNil(ledgerLookup.ledgerAccountCommoditySymbol(of: name1))

        // account does not have a commodity
        try! ledger.add(Account(name: name1))
        ledgerLookup = LedgerLookup(ledger)
        XCTAssertNil(ledgerLookup.ledgerAccountCommoditySymbol(of: name1))

        // account has a commodity
        try! ledger.add(Account(name: name2, commoditySymbol: symbol))
        ledgerLookup = LedgerLookup(ledger)
        XCTAssertNil(ledgerLookup.ledgerAccountCommoditySymbol(of: name1))
        XCTAssertEqual(ledgerLookup.ledgerAccountCommoditySymbol(of: name2), symbol)

    }

    func testLedgerAccountNameOf() {
        let name1 = try! AccountName("Assets:Test")
        let account1 = TestAccount(number: "abc", accountType: .nonRegistered, currency: "CAD")
        let ledger = Ledger()
        var ledgerLookup = LedgerLookup(ledger)

        // not found
        assert(
            try ledgerLookup.ledgerAccountName(of: account1),
            throws: WealthsimpleConversionError.missingWealthsimpleAccount("abc")
        )

        // base account
        try! ledger.add(Commodity(symbol: "XGRO"))
        try! ledger.add(Account(name: name1, metaData: ["importer-type": "wealthsimple", "number": "abc"]))
        ledgerLookup = LedgerLookup(ledger)
        XCTAssertEqual(try! ledgerLookup.ledgerAccountName(of: account1), name1)

        // commodity account
        XCTAssertEqual(try! ledgerLookup.ledgerAccountName(of: account1, symbol: "XGRO"), try! AccountName("Assets:XGRO"))

        // invalid commodity symbol
        try! ledger.add(Commodity(symbol: "XGRO:"))
        assert(
            try ledgerLookup.ledgerAccountName(of: account1, symbol: "XGRO:"),
            throws: WealthsimpleConversionError.invalidCommoditySymbol("XGRO:")
        )
    }

    func testDoesTransactionExistInLedger() {
        let ledger = Ledger()
        var metaData = TransactionMetaData(date: Date(), metaData: [MetaDataKeys.id: "abc"])
        var transaction = Transaction(metaData: metaData, postings: [])
        ledger.add(transaction)
        var ledgerLookup = LedgerLookup(ledger)

        // same transaction
        XCTAssert(ledgerLookup.doesTransactionExistInLedger(transaction))

        // different date
        metaData = TransactionMetaData(date: Date(timeIntervalSinceReferenceDate: 0), metaData: [MetaDataKeys.id: "abc"])
        transaction = Transaction(metaData: metaData, postings: [])
        XCTAssert(ledgerLookup.doesTransactionExistInLedger(transaction))

        // nrwt id
        metaData = TransactionMetaData(date: Date(), metaData: [MetaDataKeys.nrwtId: "abcd"])
        transaction = Transaction(metaData: metaData, postings: [])
        ledger.add(transaction)
        ledgerLookup = LedgerLookup(ledger)
        metaData = TransactionMetaData(date: Date(), metaData: [MetaDataKeys.id: "abcd"])
        transaction = Transaction(metaData: metaData, postings: [])
        XCTAssert(ledgerLookup.doesTransactionExistInLedger(transaction))

        // different id
        metaData = TransactionMetaData(date: Date(), metaData: [MetaDataKeys.id: "abc1"])
        transaction = Transaction(metaData: metaData, postings: [])
        XCTAssertFalse(ledgerLookup.doesTransactionExistInLedger(transaction))

        // no id
        metaData = TransactionMetaData(date: Date())
        transaction = Transaction(metaData: metaData, postings: [])
        XCTAssertFalse(ledgerLookup.doesTransactionExistInLedger(transaction))
    }

    func testDoesPriceExistInLedger() {
        let ledger = Ledger()
        let date = Date()
        var price = try! Price(date: date, commoditySymbol: "CAD", amount: Amount(number: Decimal(1), commoditySymbol: "EUR"))
        try! ledger.add(price)
        let ledgerLookup = LedgerLookup(ledger)

        // same price
        XCTAssert(ledgerLookup.doesPriceExistInLedger(price))

        // different price object with same properties
        price = try! Price(date: date, commoditySymbol: "CAD", amount: Amount(number: Decimal(1), commoditySymbol: "EUR"))
        XCTAssert(ledgerLookup.doesPriceExistInLedger(price))

        // different date
        price = try! Price(date: Date(timeIntervalSinceReferenceDate: 0), commoditySymbol: "CAD", amount: Amount(number: Decimal(1), commoditySymbol: "EUR"))
        XCTAssertFalse(ledgerLookup.doesPriceExistInLedger(price))

        // different commodity
        price = try! Price(date: date, commoditySymbol: "CAD", amount: Amount(number: Decimal(1), commoditySymbol: "USD"))
        XCTAssertFalse(ledgerLookup.doesPriceExistInLedger(price))
    }

    func testDoesBalanceExistInLedger() {
        let ledger = Ledger()
        let date = Date()
        let name = try! AccountName("Assets:TEST")
        var balance = Balance(date: date, accountName: name, amount: Amount(number: Decimal(1), commoditySymbol: "USD"))
        ledger.add(balance)
        let ledgerLookup = LedgerLookup(ledger)

        // same balance
        XCTAssert(ledgerLookup.doesBalanceExistInLedger(balance))

        // different balance object with same properties
        balance = Balance(date: date, accountName: name, amount: Amount(number: Decimal(1), commoditySymbol: "USD"))
        XCTAssert(ledgerLookup.doesBalanceExistInLedger(balance))

        // different date
        balance = Balance(date: Date(timeIntervalSinceReferenceDate: 0), accountName: name, amount: Amount(number: Decimal(1), commoditySymbol: "USD"))
        XCTAssertFalse(ledgerLookup.doesBalanceExistInLedger(balance))

        // different commodity
        balance = Balance(date: date, accountName: name, amount: Amount(number: Decimal(1), commoditySymbol: "EUR"))
        XCTAssertFalse(ledgerLookup.doesBalanceExistInLedger(balance))

        // different account
        balance = Balance(date: date, accountName: try! AccountName("Assets:TEST1"), amount: Amount(number: Decimal(1), commoditySymbol: "USD"))
        XCTAssertFalse(ledgerLookup.doesBalanceExistInLedger(balance))
    }

    func testCommoditySymbolForAssetSymbol() {
        let ledger = Ledger()
        var commodity = Commodity(symbol: "EUR")
        try! ledger.add(commodity)
        var ledgerLookup = LedgerLookup(ledger)

        // not existing
        assert(
            try ledgerLookup.commoditySymbol(for: "USD"),
            throws: WealthsimpleConversionError.missingCommodity("USD")
        )

        // fallback
        XCTAssertEqual(try! ledgerLookup.commoditySymbol(for: "EUR"), "EUR")

        // mapping exists
        commodity = Commodity(symbol: "USDABC", metaData: [MetaDataKeys.commoditySymbol: "USD"])
        try! ledger.add(commodity)
        ledgerLookup = LedgerLookup(ledger)
        XCTAssertEqual(try! ledgerLookup.commoditySymbol(for: "USD"), "USDABC")

        // mapping + fallback exists
        commodity = Commodity(symbol: "USD")
        try! ledger.add(commodity)
        ledgerLookup = LedgerLookup(ledger)
        XCTAssertEqual(try! ledgerLookup.commoditySymbol(for: "USD"), "USDABC")
    }

}
