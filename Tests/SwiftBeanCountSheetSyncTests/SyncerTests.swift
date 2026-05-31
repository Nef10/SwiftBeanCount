#if os(macOS) || os(iOS)
import Foundation
import SwiftBeanCountModel
@testable import SwiftBeanCountSheetSync
import Testing

@Suite
struct SyncerTests {

    private class TestSyncer: GenericSyncer {}

    private func createLedgerSettings(commoditySymbol: String = "CAD") throws -> LedgerSettings {
        LedgerSettings(
            commoditySymbol: commoditySymbol,
            tag: Tag(name: "shared"),
            name: "Alice",
            accountName: try AccountName("Assets:Shared"),
            dateTolerance: 86_400,
            categoryAccountNames: [:],
            accountNameCategories: [:]
        )
    }

    /// Builds a minimal sheet-derived transaction with the given own-account and shared-account amounts.
    private func sheetTransaction(
        own ownNumber: Decimal,
        shared sharedNumber: Decimal,
        commoditySymbol: String = "CAD"
    ) throws -> Transaction {
        let ownPosting = Posting(
            accountName: LedgerSettings.ownAccountName,
            amount: Amount(number: ownNumber, commoditySymbol: commoditySymbol, decimalDigits: 2)
        )
        let sharedPosting = Posting(
            accountName: try AccountName("Assets:Shared"),
            amount: Amount(number: sharedNumber, commoditySymbol: commoditySymbol, decimalDigits: 2)
        )
        let expensePosting = Posting(
            accountName: try AccountName("Expenses:Food"),
            amount: Amount(number: sharedNumber, commoditySymbol: commoditySymbol, decimalDigits: 2)
        )
        let metaData = TransactionMetaData(date: Date(), payee: "Store", narration: "", flag: .complete, tags: [])
        return Transaction(metaData: metaData, postings: [expensePosting, ownPosting, sharedPosting])
    }

    /// Builds a minimal ledger transaction (no shared posting) with the given asset amount.
    private func ledgerTransaction(asset assetNumber: Decimal, commoditySymbol: String = "CAD") throws -> Transaction {
        let assetPosting = Posting(
            accountName: LedgerSettings.ownAccountName,
            amount: Amount(number: assetNumber, commoditySymbol: commoditySymbol, decimalDigits: 2)
        )
        let expensePosting = Posting(
            accountName: try AccountName("Expenses:Food"),
            amount: Amount(number: -assetNumber, commoditySymbol: commoditySymbol, decimalDigits: 2)
        )
        let metaData = TransactionMetaData(date: Date(), payee: "Store", narration: "", flag: .complete, tags: [])
        return Transaction(metaData: metaData, postings: [expensePosting, assetPosting])
    }

    private func foreignCurrencyLedgerTransaction(asset assetNumber: Decimal, assetCommodity: String, totalPrice: Decimal, totalPriceCommodity: String) throws -> Transaction {
        let assetPosting = try Posting(
            accountName: LedgerSettings.ownAccountName,
            amount: Amount(number: assetNumber, commoditySymbol: assetCommodity, decimalDigits: 2),
            price: Amount(number: totalPrice, commoditySymbol: totalPriceCommodity, decimalDigits: 2),
            priceType: .total
        )
        let expensePosting = Posting(
            accountName: try AccountName("Expenses:Food"),
            amount: Amount(number: -totalPrice, commoditySymbol: totalPriceCommodity, decimalDigits: 2)
        )
        let metaData = TransactionMetaData(date: Date(), payee: "Store", narration: "", flag: .complete, tags: [])
        return Transaction(metaData: metaData, postings: [expensePosting, assetPosting])
    }

    private func transaction(on date: Date, payee: String) -> Transaction {
        Transaction(metaData: TransactionMetaData(date: date, payee: payee, narration: "", flag: .complete, tags: []), postings: [])
    }

    private func date(year: Int, month: Int, day: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    @Test
    func paymentMatchesExactAmount() throws {
        let settings = try createLedgerSettings()
        let syncer = TestSyncer(sheetURL: "", ledger: Ledger())
        // own = -100 (paid total), shared = 50 → exact match when ledger spent -100
        let sheet = try sheetTransaction(own: -100, shared: 50)
        let ledger = try ledgerTransaction(asset: -100)
        #expect(syncer.paymentMatches(transaction: sheet, ledgerTransaction: ledger, ledgerSettings: settings))
    }

    @Test
    func paymentMatchesShareFormatUnequalSplit() throws {
        let settings = try createLedgerSettings()
        let syncer = TestSyncer(sheetURL: "", ledger: Ledger())
        // Share format: own = -2×30.63 = -61.26, shared = 30.63
        // Ledger actually shows the real total: -100 (unequal split)
        let sheet = try sheetTransaction(own: -61.26, shared: 30.63)
        let ledger = try ledgerTransaction(asset: -100)
        #expect(syncer.paymentMatches(transaction: sheet, ledgerTransaction: ledger, ledgerSettings: settings))
    }

    @Test
    func paymentMatchesReturnsFalseWhenShareExceedsTotal() throws {
        let settings = try createLedgerSettings()
        let syncer = TestSyncer(sheetURL: "", ledger: Ledger())
        // share (30.63) > |moneySpend| (20) → invalid, no match
        let sheet = try sheetTransaction(own: -61.26, shared: 30.63)
        let ledger = try ledgerTransaction(asset: -20)
        #expect(!syncer.paymentMatches(transaction: sheet, ledgerTransaction: ledger, ledgerSettings: settings))
    }

    @Test
    func paymentMatchesReturnsFalseForNonShareFormatMismatch() throws {
        let settings = try createLedgerSettings()
        let syncer = TestSyncer(sheetURL: "", ledger: Ledger())
        // own = -61.26, shared = 20 → own ≠ -2×shared (not share format signature), and own ≠ moneySpend
        let sheet = try sheetTransaction(own: -61.26, shared: 20)
        let ledger = try ledgerTransaction(asset: -100)
        #expect(!syncer.paymentMatches(transaction: sheet, ledgerTransaction: ledger, ledgerSettings: settings))
    }

    @Test
    func paymentMatchesReturnsFalseForCommodityMismatch() throws {
        let settings = try createLedgerSettings(commoditySymbol: "CAD")
        let syncer = TestSyncer(sheetURL: "", ledger: Ledger())
        // Sheet uses USD, ledger uses CAD → commodity mismatch
        let sheet = try sheetTransaction(own: -61.26, shared: 30.63, commoditySymbol: "USD")
        let ledger = try ledgerTransaction(asset: -100, commoditySymbol: "CAD")
        #expect(!syncer.paymentMatches(transaction: sheet, ledgerTransaction: ledger, ledgerSettings: settings))
    }

    @Test
    func paymentMatchesUsesTotalPriceWhenLedgerPostingAmountIsForeignCurrency() throws {
        let settings = try createLedgerSettings(commoditySymbol: "CAD")
        let syncer = TestSyncer(sheetURL: "", ledger: Ledger())
        let sheet = try sheetTransaction(own: -13, shared: 6.5, commoditySymbol: "CAD")
        let ledger = try foreignCurrencyLedgerTransaction(asset: -10, assetCommodity: "USD", totalPrice: -13, totalPriceCommodity: "CAD")
        #expect(syncer.paymentMatches(transaction: sheet, ledgerTransaction: ledger, ledgerSettings: settings))
    }

    @Test
    func removeExistingTransactionsMatchesCaseInsensitivePayee() throws {
        let settings = try createLedgerSettings()
        let syncer = TestSyncer(sheetURL: "", ledger: Ledger())
        let date = Date()
        let amount = Amount(number: 9.98, commoditySymbol: "CAD", decimalDigits: 2)
        let sharedPosting = Posting(accountName: try AccountName("Assets:Shared"), amount: amount)
        let sheetTx = Transaction(
            metaData: TransactionMetaData(date: date, payee: "Save on Foods", narration: "Hike"),
            postings: [sharedPosting]
        )
        let ledgerTx = Transaction(
            metaData: TransactionMetaData(date: date, payee: "Save On Foods", narration: "Hike"),
            postings: [sharedPosting]
        )
        let filtered = syncer.removeExistingTransactions(from: [sheetTx], existingTransactions: [ledgerTx], ledgerSettings: settings)
        #expect(filtered.isEmpty)
    }

    @Test
    func removeExistingTransactionsMatchesSecondSharedPosting() throws {
        let settings = try createLedgerSettings()
        let syncer = TestSyncer(sheetURL: "", ledger: Ledger())
        let date = Date()
        let sharedAccount = try AccountName("Assets:Shared")
        let amount1 = Amount(number: 17.34, commoditySymbol: "CAD", decimalDigits: 2)
        let amount2 = Amount(number: 16.87, commoditySymbol: "CAD", decimalDigits: 2)
        // Ledger transaction has TWO shared postings with different amounts
        let ledgerTx = Transaction(
            metaData: TransactionMetaData(date: date, payee: "T&T", narration: ""),
            postings: [Posting(accountName: sharedAccount, amount: amount1), Posting(accountName: sharedAccount, amount: amount2)]
        )
        let sheetTx1 = Transaction(
            metaData: TransactionMetaData(date: date, payee: "T&T", narration: ""),
            postings: [Posting(accountName: sharedAccount, amount: amount1)]
        )
        let sheetTx2 = Transaction(
            metaData: TransactionMetaData(date: date, payee: "T&T", narration: ""),
            postings: [Posting(accountName: sharedAccount, amount: amount2)]
        )
        let filtered = syncer.removeExistingTransactions(from: [sheetTx1, sheetTx2], existingTransactions: [ledgerTx], ledgerSettings: settings)
        #expect(filtered.isEmpty)
    }

    @Test
    func ledgerTransactionForCorrectMonthUsesDominantMonth() {
        let syncer = TestSyncer(sheetURL: "", ledger: Ledger())
        let calendar = Calendar(identifier: .gregorian)
        let januaryTransactions = [
            transaction(on: calendar.date(from: DateComponents(year: 2_024, month: 1, day: 3))!, payee: "January 1"),
            transaction(on: calendar.date(from: DateComponents(year: 2_024, month: 1, day: 12))!, payee: "January 2"),
            transaction(on: calendar.date(from: DateComponents(year: 2_024, month: 1, day: 27))!, payee: "January 3")
        ]
        let februaryTransaction = transaction(on: calendar.date(from: DateComponents(year: 2_024, month: 2, day: 2))!, payee: "February")

        let filtered = syncer.ledgerTransactionForCorrectMonth(
            ledgerTransactions: januaryTransactions + [februaryTransaction],
            sheetTransactions: januaryTransactions + [februaryTransaction]
        )

        #expect(filtered.count == 3)
        #expect(filtered.allSatisfy { calendar.component(.month, from: $0.metaData.date) == 1 })
    }

    @Test
    func balanceDateReturnsNextDay() {
        let syncer = TestSyncer(sheetURL: "", ledger: Ledger())
        let calendar = Calendar(identifier: .gregorian)
        let transactionDate = calendar.date(from: DateComponents(year: 2_024, month: 5, day: 24))!

        let balanceDate = syncer.balanceDate(after: transactionDate)

        #expect(balanceDate == calendar.date(from: DateComponents(year: 2_024, month: 5, day: 25))!)
    }

    @Test
    func isMonthlySheetReturnsTrueAtNinetyPercentThreshold() {
        let syncer = TestSyncer(sheetURL: "", ledger: Ledger())
        let transactions = (1 ... 9).map { day in
            transaction(on: date(year: 2_024, month: 1, day: day), payee: "January \(day)")
        } + [transaction(on: date(year: 2_024, month: 2, day: 1), payee: "February")]

        #expect(syncer.isMonthlySheet(transactions))
    }

    @Test
    func isMonthlySheetReturnsFalseBelowNinetyPercentThreshold() {
        let syncer = TestSyncer(sheetURL: "", ledger: Ledger())
        let transactions = (1 ... 8).map { day in
            transaction(on: date(year: 2_024, month: 1, day: day), payee: "January \(day)")
        } + [transaction(on: date(year: 2_024, month: 2, day: 1), payee: "February")]

        #expect(!syncer.isMonthlySheet(transactions))
    }

}
#endif
