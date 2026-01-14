import Foundation
import SwiftBeanCountModel
@testable import SwiftBeanCountSheetSync
import Testing

@Suite
struct SyncResultTests {

    @Test
    func syncResultInitialization() throws {
        let transactions = [
            Transaction(metaData: TransactionMetaData(date: Date(), payee: "Test", narration: ""), postings: [])
        ]
        let parserErrors = [SheetParserError.invalidValue("test")]
        let ledgerSettings = LedgerSettings(
            commoditySymbol: "USD",
            tag: Tag(name: "test"),
            name: "Alice",
            accountName: try AccountName("Assets:Test"),
            dateTolerance: 86_400,
            categoryAccountNames: [:],
            accountNameCategories: [:]
        )

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
    }

}
