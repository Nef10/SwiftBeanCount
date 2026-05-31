#if os(macOS) || os(iOS)
import Foundation
import SwiftBeanCountModel
@testable import SwiftBeanCountSheetSync
import Testing

@Suite
struct SheetCellsFormatterForeignCurrencyTests {

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
                "Parking": try AccountName("Expenses:Transportation:Car:Parking")
            ],
            accountNameCategories: [
                "Expenses:Groceries": "Groceries",
                "Expenses:Transportation:Car:Parking": "Parking"
            ]
        )
    }

    private func ownerPaidForeignCurrencyTransaction() throws -> Transaction {
        Transaction(
            metaData: TransactionMetaData(date: Date(timeIntervalSince1970: 1_735_689_600), payee: "Store", narration: "Weekly shop"),
            postings: [
                Posting(accountName: try AccountName("Expenses:Groceries"),
                        amount: Amount(number: Decimal(string: "13.00")!, commoditySymbol: "CAD", decimalDigits: 2)
                ),
                try Posting(accountName: LedgerSettings.ownAccountName,
                            amount: Amount(number: Decimal(string: "-10.00")!, commoditySymbol: "USD", decimalDigits: 2),
                            price: Amount(number: Decimal(string: "-13.00")!, commoditySymbol: "CAD", decimalDigits: 2),
                            priceType: .total
                ),
                Posting(accountName: try AccountName("Assets:Shared"),
                        amount: Amount(number: Decimal(string: "6.50")!, commoditySymbol: "CAD", decimalDigits: 2)
                )
            ]
        )
    }

    private func ownerPaidForeignCurrencyCardTransactionWithoutSyncPostings() throws -> Transaction {
        Transaction(
            metaData: TransactionMetaData(date: Date(timeIntervalSince1970: 1_747_347_200), payee: "City of Vancouver", narration: "PayByPhone - Fountainhead Ash"),
            postings: [
                try Posting(accountName: try AccountName("Liabilities:CreditCard:Wealthsimple"),
                            amount: Amount(number: Decimal(string: "-10.00")!, commoditySymbol: "USD", decimalDigits: 2),
                            price: Amount(number: Decimal(string: "-13.00")!, commoditySymbol: "CAD", decimalDigits: 2),
                            priceType: .total
                ),
                Posting(accountName: try AccountName("Expenses:Transportation:Car:Parking"),
                        amount: Amount(number: Decimal(string: "13.00")!, commoditySymbol: "CAD", decimalDigits: 2)
                )
            ]
        )
    }

    @Test
    func buildUploadSheetCellsUsesTotalPriceWhenOwnerPostingAmountIsForeignCurrency() throws {
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

        let result = try SheetCellsFormatter.buildUploadSheetCells(
            syncer: syncer,
            layout: layout,
            transactions: [try ownerPaidForeignCurrencyTransaction()],
            ledgerSettings: try makeLedgerSettings()
        )

        #expect(result.errors.isEmpty)
        #expect(result.transactions.count == 1)
        #expect(result.sheetCells == [
            ["Date", "Payee", "Amount", "Category", "Payor", "Description"],
            ["2025-01-01", "Store", "13.00", "Groceries", "Alice", "Weekly shop"]
        ])
    }

    @Test
    func buildUploadSheetCellsUsesTotalPriceForForeignCurrencyCardPayment() throws {
        let syncer = TestSyncer(sheetURL: "", ledger: Ledger())
        let data = [
            ["Date", "Description", "Payee", "Category", "Payor", "Share Other Person", "Running Total"],
            ["2025-01-01", "Existing row", "Store", "", "Bob", "1.00", "1.00"]
        ]
        let parsed = SheetParser.parseSheetData(data, name: "Alice")
        let result = try SheetCellsFormatter.buildUploadSheetCells(
            syncer: syncer,
            layout: parsed.layout,
            transactions: [try ownerPaidForeignCurrencyCardTransactionWithoutSyncPostings()],
            ledgerSettings: try makeLedgerSettings()
        )

        #expect(result.errors.isEmpty)
        #expect(result.transactions.count == 1)
        #expect(result.sheetCells == [
            ["Date", "Description", "Payee", "Category", "Payor", "Share Other Person"],
            ["2025-05-15", "PayByPhone - Fountainhead Ash", "City of Vancouver", "Parking", "Alice", "6.50"]
        ])
    }

}
#endif
