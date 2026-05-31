#if os(macOS) || os(iOS)
import Foundation
import SwiftBeanCountModel
@testable import SwiftBeanCountSheetSync
import Testing

@Suite
struct SheetCellsFormatterSplitUploadTests {

    private class TestSyncer: GenericSyncer {}

    private func makeLedgerSettings() throws -> LedgerSettings {
        LedgerSettings(
            commoditySymbol: "CAD",
            tag: Tag(name: "shared"),
            name: "Alice",
            accountName: try AccountName("Assets:Shared"),
            dateTolerance: 86_400,
            categoryAccountNames: [
                "Groceries": try AccountName("Expenses:Groceries"),
                "Dining": try AccountName("Expenses:Dining")
            ],
            accountNameCategories: [
                "Expenses:Groceries": "Groceries",
                "Expenses:Dining": "Dining"
            ]
        )
    }

    private func ownerPaidSplitTransaction() throws -> Transaction {
        Transaction(
            metaData: TransactionMetaData(date: Date(timeIntervalSince1970: 1_735_689_600), payee: "Store", narration: "Weekly shop"),
            postings: [
                Posting(accountName: try AccountName("Expenses:Groceries"),
                        amount: Amount(number: Decimal(string: "30.63")!, commoditySymbol: "CAD", decimalDigits: 2)
                ),
                Posting(accountName: try AccountName("Expenses:Dining"),
                        amount: Amount(number: Decimal(string: "10.00")!, commoditySymbol: "CAD", decimalDigits: 2)
                ),
                Posting(accountName: LedgerSettings.ownAccountName,
                        amount: Amount(number: Decimal(string: "-81.26")!, commoditySymbol: "CAD", decimalDigits: 2)
                ),
                Posting(accountName: try AccountName("Assets:Shared"),
                        amount: Amount(number: Decimal(string: "40.63")!, commoditySymbol: "CAD", decimalDigits: 2)
                )
            ]
        )
    }

    @Test
    func buildUploadSheetCellsSplitsShareFormatRowsForMultipleExpensePostings() throws {
        let syncer = TestSyncer(sheetURL: "", ledger: Ledger())
        let data = [
            ["Date", "Description", "Payee", "Category", "Payor", "Share Other Person", "Running Total"],
            ["2025-01-01", "Existing row", "Store", "Groceries", "Bob", "30.63", "30.63"]
        ]
        let parsed = SheetParser.parseSheetData(data, name: "Alice")
        let transaction = try ownerPaidSplitTransaction()
        let result = try SheetCellsFormatter.buildUploadSheetCells(
            syncer: syncer,
            layout: parsed.layout,
            transactions: [transaction],
            ledgerSettings: try makeLedgerSettings()
        )

        #expect(result.errors.isEmpty)
        #expect(result.transactions == [transaction])
        #expect(result.sheetCells == [
            ["Date", "Description", "Payee", "Category", "Payor", "Share Other Person"],
            ["2025-01-01", "Weekly shop", "Store", "Groceries", "Alice", "30.63"],
            ["2025-01-01", "Weekly shop", "Store", "Dining", "Alice", "10.00"]
        ])
    }

    @Test
    func buildUploadSheetCellsSplitsTotalAmountRowsForMultipleExpensePostings() throws {
        let syncer = TestSyncer(sheetURL: "", ledger: Ledger())
        let layout = SheetCellsFormatter.Layout(
            format: .totalAmount,
            columns: [
                SheetCellsFormatter.Column(header: "Date", index: 0, role: .date),
                SheetCellsFormatter.Column(header: "Payee", index: 1, role: .payee),
                SheetCellsFormatter.Column(header: "Amount", index: 2, role: .amount),
                SheetCellsFormatter.Column(header: "Category", index: 3, role: .category),
                SheetCellsFormatter.Column(header: "Payor", index: 4, role: .payer),
                SheetCellsFormatter.Column(header: "Description", index: 5, role: .narration)
            ],
            otherPersonName: "Bob"
        )
        let transaction = try ownerPaidSplitTransaction()
        let result = try SheetCellsFormatter.buildUploadSheetCells(
            syncer: syncer,
            layout: layout,
            transactions: [transaction],
            ledgerSettings: try makeLedgerSettings()
        )

        #expect(result.errors.isEmpty)
        #expect(result.transactions == [transaction])
        #expect(result.sheetCells == [
            ["Date", "Payee", "Amount", "Category", "Payor", "Description"],
            ["2025-01-01", "Store", "61.26", "Groceries", "Alice", "Weekly shop"],
            ["2025-01-01", "Store", "20.00", "Dining", "Alice", "Weekly shop"]
        ])
    }

}
#endif
