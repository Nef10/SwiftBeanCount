import Foundation
import SwiftBeanCountModel
@testable import SwiftBeanCountWealthsimpleMapper
import Testing
import Wealthsimple

struct TestAccount: Wealthsimple.Account {
    var accountType = Wealthsimple.AccountType.nonRegistered
    var number = ""
    var id = ""
    var currency = ""
}

@Suite
struct LedgerLookupTests {

    private let accountName = try! AccountName("Assets:Test") // swiftlint:disable:this force_try

   @Test
   func testLedgerAccountCommoditySymbol() throws {
        let ledger = Ledger()
        var ledgerLookup = LedgerLookup(ledger)

        let name2 = try AccountName("Assets:Test1")
        let symbol = "CAD"

        // account does not exist
        #expect(ledgerLookup.ledgerAccountCommoditySymbol(of: accountName) == nil)

        // account does not have a commodity
        try ledger.add(Account(name: accountName))
        ledgerLookup = LedgerLookup(ledger)
        #expect(ledgerLookup.ledgerAccountCommoditySymbol(of: accountName) == nil)

        // account has a commodity
        try ledger.add(Account(name: name2, commoditySymbol: symbol))
        ledgerLookup = LedgerLookup(ledger)
        #expect(ledgerLookup.ledgerAccountCommoditySymbol(of: accountName) == nil)
        #expect(ledgerLookup.ledgerAccountCommoditySymbol(of: name2) == symbol)

    }

   @Test
   func testLedgerAccountNameOf() throws {
        let ledger = Ledger()
        var ledgerLookup = LedgerLookup(ledger)

        let account = TestAccount(number: "abc")

        // not found
        #expect(throws: WealthsimpleConversionError.missingWealthsimpleAccount("abc")) {
            try ledgerLookup.ledgerAccountName(of: account)
        }

        // base account
        try ledger.add(Commodity(symbol: "XGRO"))
        try ledger.add(Account(name: accountName, metaData: ["importer-type": "wealthsimple", "number": "abc"]))
        ledgerLookup = LedgerLookup(ledger)
        #expect(try ledgerLookup.ledgerAccountName(of: account) == accountName)

        // commodity account
        let expectedAccountName = try AccountName("Assets:XGRO")
        #expect(try ledgerLookup.ledgerAccountName(of: account, symbol: "XGRO") == expectedAccountName)

        // invalid commodity symbol
        try ledger.add(Commodity(symbol: "XGRO:"))
        #expect(throws: WealthsimpleConversionError.invalidCommoditySymbol("XGRO:")) {
            try ledgerLookup.ledgerAccountName(of: account, symbol: "XGRO:")
        }
    }

   @Test
   func testLedgerAccountNameFor() throws { // swiftlint:disable:this function_body_length
        let ledger = Ledger()
        var ledgerLookup = LedgerLookup(ledger)

        var number = "abc123"

        // fallback for payment spend
        #expect(try ledgerLookup.ledgerAccountName(for: .transactionType(.paymentSpend), in: TestAccount(number: number), ofType: [.expense] ) ==
                       WealthsimpleLedgerMapper.fallbackExpenseAccountName)

        // not found
        #expect(throws: WealthsimpleConversionError.missingAccount(MetaDataKeys.rounding, number, "Income")) {
            try ledgerLookup.ledgerAccountName(for: .rounding, in: TestAccount(number: number), ofType: [.income])
        }
        #expect(throws: WealthsimpleConversionError.missingAccount("\(MetaDataKeys.prefix)\(TransactionType.dividend)", number, "Income")) {
            try ledgerLookup.ledgerAccountName(for: .transactionType(.dividend), in: TestAccount(number: number), ofType: [.income])
        }

        // rounding
        try ledger.add(Account(name: accountName, metaData: [MetaDataKeys.rounding: number]))
        ledgerLookup = LedgerLookup(ledger)
        #expect(try ledgerLookup.ledgerAccountName(for: .rounding, in: TestAccount(number: number), ofType: [.asset] ) == accountName)

        // wrong type
        #expect(throws: WealthsimpleConversionError.missingAccount(MetaDataKeys.rounding, number, "Income, or Expenses, or Equity")) {
            try ledgerLookup.ledgerAccountName(for: .rounding, in: TestAccount(number: number), ofType: [.income, .expense, .equity])
        }

        // multiple numbers
        var name = try AccountName("Assets:Test:Two")
        number = "def456"
        let number2 = "ghi789"
        try ledger.add(Account(name: name, metaData: [MetaDataKeys.rounding: "\(number) \(number2)"]))
        ledgerLookup = LedgerLookup(ledger)
        #expect(try ledgerLookup.ledgerAccountName(for: .rounding, in: TestAccount(number: number), ofType: [.asset] ) == name)
        #expect(try ledgerLookup.ledgerAccountName(for: .rounding, in: TestAccount(number: number2), ofType: [.asset] ) == name)

        // contribution room
        name = try AccountName("Assets:Test:Three")
        try ledger.add(Account(name: name, metaData: [MetaDataKeys.contributionRoom: number]))
        ledgerLookup = LedgerLookup(ledger)
        #expect(try ledgerLookup.ledgerAccountName(for: .contributionRoom, in: TestAccount(number: number), ofType: [.asset] ) == name)

        // dividend + transaction type multi key
        name = try AccountName("Income:Test")
        let symbol = "XGRO"
        try ledger.add(Account(name: name, metaData: ["\(MetaDataKeys.dividendPrefix)\(symbol)": number, "\(MetaDataKeys.prefix)giveaway-bonus": number]))
        try ledger.add(Commodity(symbol: symbol))
        ledgerLookup = LedgerLookup(ledger)
        #expect(try ledgerLookup.ledgerAccountName(for: .dividend(symbol), in: TestAccount(number: number), ofType: [.income] ) == name)
        #expect(try ledgerLookup.ledgerAccountName(for: .transactionType(.giveawayBonus), in: TestAccount(number: number), ofType: [.income] ) == name)
    }

   @Test
   func testDoesTransactionExistInLedger() {
        let ledger = Ledger()
        var ledgerLookup = LedgerLookup(ledger)

        var metaData = TransactionMetaData(date: Date(), metaData: [MetaDataKeys.id: "abc"])
        var transaction = Transaction(metaData: metaData, postings: [])
        ledger.add(transaction)
        var ledgerLookup = LedgerLookup(ledger)

        // same transaction
        #expect(ledgerLookup.doesTransactionExistInLedger(transaction))

        // different date
        metaData = TransactionMetaData(date: Date(timeIntervalSinceReferenceDate: 0), metaData: [MetaDataKeys.id: "abc"])
        transaction = Transaction(metaData: metaData, postings: [])
        #expect(ledgerLookup.doesTransactionExistInLedger(transaction))

        // nrwt id
        metaData = TransactionMetaData(date: Date(), metaData: [MetaDataKeys.nrwtId: "abcd"])
        transaction = Transaction(metaData: metaData, postings: [])
        ledger.add(transaction)
        ledgerLookup = LedgerLookup(ledger)
        metaData = TransactionMetaData(date: Date(), metaData: [MetaDataKeys.id: "abcd"])
        transaction = Transaction(metaData: metaData, postings: [])
        #expect(ledgerLookup.doesTransactionExistInLedger(transaction))

        // different id
        metaData = TransactionMetaData(date: Date(), metaData: [MetaDataKeys.id: "abc1"])
        transaction = Transaction(metaData: metaData, postings: [])
        #expect(!(ledgerLookup.doesTransactionExistInLedger(transaction)))

        // no id
        metaData = TransactionMetaData(date: Date())
        transaction = Transaction(metaData: metaData, postings: [])
        #expect(!(ledgerLookup.doesTransactionExistInLedger(transaction)))
    }

   @Test
   func testDoesPriceExistInLedger() throws {
        let ledger = Ledger()
        var ledgerLookup = LedgerLookup(ledger)

        let date = Date()
        var price = try Price(date: date, commoditySymbol: "CAD", amount: Amount(number: Decimal(1), commoditySymbol: "EUR"))
        try ledger.add(price)
        ledgerLookup = LedgerLookup(ledger)

        // same price
        #expect(ledgerLookup.doesPriceExistInLedger(price))

        // different price object with same properties
        price = try Price(date: date, commoditySymbol: "CAD", amount: Amount(number: Decimal(1), commoditySymbol: "EUR"))
        #expect(ledgerLookup.doesPriceExistInLedger(price))

        // different date
        price = try Price(date: Date(timeIntervalSinceReferenceDate: 0), commoditySymbol: "CAD", amount: Amount(number: Decimal(1), commoditySymbol: "EUR"))
        #expect(!(ledgerLookup.doesPriceExistInLedger(price)))

        // different commodity
        price = try Price(date: date, commoditySymbol: "CAD", amount: Amount(number: Decimal(1), commoditySymbol: "USD"))
        #expect(!(ledgerLookup.doesPriceExistInLedger(price)))
    }

   @Test
   func testDoesBalanceExistInLedger() throws {
        let ledger = Ledger()
        var ledgerLookup = LedgerLookup(ledger)

        let date = Date()
        var balance = Balance(date: date, accountName: accountName, amount: Amount(number: Decimal(1), commoditySymbol: "USD"))
        ledger.add(balance)
        ledgerLookup = LedgerLookup(ledger)

        // same balance
        #expect(ledgerLookup.doesBalanceExistInLedger(balance))

        // different balance object with same properties
        balance = Balance(date: date, accountName: accountName, amount: Amount(number: Decimal(1), commoditySymbol: "USD"))
        #expect(ledgerLookup.doesBalanceExistInLedger(balance))

        // different date
        balance = Balance(date: Date(timeIntervalSinceReferenceDate: 0), accountName: accountName, amount: Amount(number: Decimal(1), commoditySymbol: "USD"))
        #expect(!(ledgerLookup.doesBalanceExistInLedger(balance)))

        // different commodity
        balance = Balance(date: date, accountName: accountName, amount: Amount(number: Decimal(1), commoditySymbol: "EUR"))
        #expect(!(ledgerLookup.doesBalanceExistInLedger(balance)))

        // different account
        balance = Balance(date: date, accountName: try AccountName("Assets:TEST1"), amount: Amount(number: Decimal(1), commoditySymbol: "USD"))
        #expect(!(ledgerLookup.doesBalanceExistInLedger(balance)))
    }

   @Test
   func testCommoditySymbolForAssetSymbol() throws {
        let ledger = Ledger()
        var ledgerLookup = LedgerLookup(ledger)

        var commodity = Commodity(symbol: "EUR")
        try ledger.add(commodity)
        ledgerLookup = LedgerLookup(ledger)

        // not existing
        #expect(throws: WealthsimpleConversionError.missingCommodity("USD")) {
            try ledgerLookup.commoditySymbol(for: "USD")
        }

        // fallback
        #expect(try ledgerLookup.commoditySymbol(for: "EUR") == "EUR")

        // mapping exists
        commodity = Commodity(symbol: "USDABC", metaData: [MetaDataKeys.commoditySymbol: "USD"])
        try ledger.add(commodity)
        ledgerLookup = LedgerLookup(ledger)
        #expect(try ledgerLookup.commoditySymbol(for: "USD") == "USDABC")

        // mapping + fallback exists
        commodity = Commodity(symbol: "USD")
        try ledger.add(commodity)
        ledgerLookup = LedgerLookup(ledger)
        #expect(try ledgerLookup.commoditySymbol(for: "USD") == "USDABC")
    }

}
