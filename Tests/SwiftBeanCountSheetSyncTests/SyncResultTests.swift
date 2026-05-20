import Foundation
import SwiftBeanCountModel
@testable import SwiftBeanCountSheetSync
import Testing

@Suite
struct SyncResultTests {

    private func makeLedgerSettings() throws -> LedgerSettings {
        LedgerSettings(
            commoditySymbol: "USD",
            tag: Tag(name: "test"),
            name: "Alice",
            accountName: try AccountName("Assets:Test"),
            dateTolerance: 86_400,
            categoryAccountNames: [:],
            accountNameCategories: [:]
        )
    }

    @Test
    func syncResultInitialization() throws {
        let transactions = [
            Transaction(metaData: TransactionMetaData(date: Date(), payee: "Test", narration: ""), postings: [])
        ]
        let parserErrors = [SheetParserError.invalidValue("test")]
        let ledgerSettings = try makeLedgerSettings()

        let result = SyncResult(
            mode: .download,
            transactions: transactions,
            parserErrors: parserErrors,
            ledgerSettings: ledgerSettings
        )

        #expect(result.mode == .download)
        #expect(result.transactions.count == 1)
        #expect(result.transactions == transactions)
        #expect(result.parserErrors.count == 1)
        #expect(result.parserErrors == parserErrors)
        #expect(result.ledgerSettings == ledgerSettings)
        #expect(result.balance == nil)
    }

    @Test
    func syncResultWithBalance() throws {
        let ledgerSettings = try makeLedgerSettings()
        let balanceDate = Date(timeIntervalSince1970: 1_705_276_800)
        let amount = Amount(number: Decimal(string: "42.50")!, commoditySymbol: "USD", decimalDigits: 2)
        let balance = Balance(date: balanceDate, accountName: try AccountName("Assets:Test"), amount: amount)

        let result = SyncResult(
            mode: .download,
            transactions: [],
            parserErrors: [],
            ledgerSettings: ledgerSettings,
            balance: balance
        )

        #expect(result.balance != nil)
        #expect(result.balance?.amount.number == Decimal(string: "42.50")!)
        #expect(result.balance?.amount.commoditySymbol == "USD")
        #expect(result.balance?.date == balanceDate)
    }

    @Test
    func syncResultUploadMode() throws {
        let ledgerSettings = try makeLedgerSettings()

        let result = SyncResult(
            mode: .upload,
            transactions: [],
            parserErrors: [],
            ledgerSettings: ledgerSettings
        )

        #expect(result.mode == .upload)
        #expect(result.balance == nil)
    }

}
