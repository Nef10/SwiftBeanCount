#if os(macOS) || os(iOS)
import Foundation
import SwiftBeanCountModel
@testable import SwiftBeanCountSheetSync
import Testing

@Suite
struct SheetCellsFormatterTests {

    private class TestSyncer: GenericSyncer {}

    private func makeLedgerSettings() throws -> LedgerSettings {
        LedgerSettings(
            commoditySymbol: "CAD",
            tag: Tag(name: "shared"),
            name: "Alice",
            accountName: try AccountName("Assets:Shared"),
            dateTolerance: 86_400,
            categoryAccountNames: ["Groceries": try AccountName("Expenses:Groceries")],
            accountNameCategories: ["Expenses:Groceries": "Groceries"]
        )
    }

    private func ownerPaidTransaction() throws -> Transaction {
        Transaction(
            metaData: TransactionMetaData(date: Date(timeIntervalSince1970: 1_735_689_600), payee: "Store", narration: "Weekly shop"),
            postings: [
                Posting(accountName: try AccountName("Expenses:Groceries"),
                        amount: Amount(number: Decimal(string: "30.63")!, commoditySymbol: "CAD", decimalDigits: 2)
                ),
                Posting(accountName: LedgerSettings.ownAccountName,
                        amount: Amount(number: Decimal(string: "-61.26")!, commoditySymbol: "CAD", decimalDigits: 2)
                ),
                Posting(accountName: try AccountName("Assets:Shared"),
                        amount: Amount(number: Decimal(string: "30.63")!, commoditySymbol: "CAD", decimalDigits: 2)
                )
            ]
        )
    }

    private func otherPaidTransaction() throws -> Transaction {
        Transaction(
            metaData: TransactionMetaData(date: Date(timeIntervalSince1970: 1_735_689_600), payee: "Store", narration: "Weekly shop"),
            postings: [
                Posting(accountName: try AccountName("Expenses:Groceries"),
                        amount: Amount(number: Decimal(string: "30.63")!, commoditySymbol: "CAD", decimalDigits: 2)
                ),
                Posting(accountName: try AccountName("Assets:Shared"),
                        amount: Amount(number: Decimal(string: "-30.63")!, commoditySymbol: "CAD", decimalDigits: 2)
                )
            ]
        )
    }

    private func ownerPaidTransactionWithoutSharedPosting() throws -> Transaction {
        Transaction(
            metaData: TransactionMetaData(date: Date(timeIntervalSince1970: 1_735_689_600), payee: "Store", narration: "Weekly shop"),
            postings: [
                Posting(accountName: try AccountName("Expenses:Groceries"),
                        amount: Amount(number: Decimal(string: "61.26")!, commoditySymbol: "CAD", decimalDigits: 2)
                ),
                Posting(accountName: LedgerSettings.ownAccountName,
                        amount: Amount(number: Decimal(string: "-61.26")!, commoditySymbol: "CAD", decimalDigits: 2)
                )
            ]
        )
    }

    private func ownerPaidTransactionWithoutOwnPosting() throws -> Transaction {
        Transaction(
            metaData: TransactionMetaData(date: Date(timeIntervalSince1970: 1_735_689_600), payee: "Store", narration: "Weekly shop"),
            postings: [
                Posting(accountName: try AccountName("Expenses:Groceries"),
                        amount: Amount(number: Decimal(string: "30.63")!, commoditySymbol: "CAD", decimalDigits: 2)
                ),
                Posting(accountName: try AccountName("Assets:Shared"),
                        amount: Amount(number: Decimal(string: "30.63")!, commoditySymbol: "CAD", decimalDigits: 2)
                )
            ]
        )
    }

    private func ownerPaidCardTransactionWithoutSyncPostings() throws -> Transaction {
        Transaction(
            metaData: TransactionMetaData(date: Date(timeIntervalSince1970: 1_747_347_200), payee: "City of Vancouver", narration: "PayByPhone - Fountainhead Ash"),
            postings: [
                Posting(accountName: try AccountName("Liabilities:CreditCard:Wealthsimple"),
                        amount: Amount(number: Decimal(string: "-2.00")!, commoditySymbol: "CAD", decimalDigits: 2)
                ),
                Posting(accountName: try AccountName("Expenses:Transportation:Car:Parking"),
                        amount: Amount(number: Decimal(string: "2.00")!, commoditySymbol: "CAD", decimalDigits: 2)
                )
            ]
        )
    }

    @Test
    func buildDownloadSheetCellsProjectsOnlyIncludedColumns() throws {
        let syncer = TestSyncer(sheetURL: "", ledger: Ledger())
        let data = [
            ["Date", "Payee", "Amount", "Category", "Payor", "Description", "Part Alice", "Part Bob", "Running Total"],
            ["2025-01-01", "Filtered Store", "CA$61.26", "Groceries", "Bob", "Filtered row", "30.63", "30.63", "CA$30.63"],
            ["2025-01-02", "Kept Store", "CA$10.00", "Groceries", "Alice", "Keep this row", "5.00", "5.00", "CA$35.63"]
        ]
        let parsed = SheetParser.parseSheetData(data, name: "Alice")
        let ledgerSettings = try makeLedgerSettings()
        let transactions = TransactionMapper.mapDataToTransactions(parsed.rows.map(\.transactionData), ledgerSettings: ledgerSettings)
        let rows = Array(zip(transactions, parsed.rows).map {
            SheetCellsFormatter.MappedRow(transaction: $0.0, rawRow: $0.1.rawRow)
        })
        let filteredRows = syncer.removeExistingRows(
            from: rows,
            existingTransactions: [transactions[0]],
            ledgerSettings: ledgerSettings
        )

        let cells = SheetCellsFormatter.buildDownloadSheetCells(layout: parsed.layout, rows: filteredRows)

        #expect(cells == [
            ["Date", "Payee", "Amount", "Category", "Payor", "Description"],
            ["2025-01-02", "Kept Store", "CA$10.00", "Groceries", "Alice", "Keep this row"]
        ])
    }

    @Test
    func buildUploadSheetCellsUsesTemplateHeadersForShareFormat() throws {
        let syncer = TestSyncer(sheetURL: "", ledger: Ledger())
        let data = [
            ["Date", "Description", "Payee", "Category", "Payor", "Share Other Person", "Running Total"],
            ["2025-01-01", "Existing row", "Store", "Groceries", "Bob", "30.63", "30.63"]
        ]
        let parsed = SheetParser.parseSheetData(data, name: "Alice")
        let result = try SheetCellsFormatter.buildUploadSheetCells(
            syncer: syncer,
            layout: parsed.layout,
            transactions: [try ownerPaidTransaction()],
            ledgerSettings: try makeLedgerSettings()
        )

        #expect(result.errors.isEmpty)
        #expect(result.transactions.count == 1)
        #expect(result.sheetCells == [
            ["Date", "Description", "Payee", "Category", "Payor", "Share Other Person"],
            ["2025-01-01", "Weekly shop", "Store", "Groceries", "Alice", "30.63"]
        ])
    }

    @Test
    func buildUploadSheetCellsUsesHalfAmountWhenSharePostingIsMissing() throws {
        let syncer = TestSyncer(sheetURL: "", ledger: Ledger())
        let data = [
            ["Date", "Description", "Payee", "Category", "Payor", "Share Other Person", "Running Total"],
            ["2025-01-01", "Existing row", "Store", "Groceries", "Bob", "30.63", "30.63"]
        ]
        let parsed = SheetParser.parseSheetData(data, name: "Alice")
        let result = try SheetCellsFormatter.buildUploadSheetCells(
            syncer: syncer,
            layout: parsed.layout,
            transactions: [try ownerPaidTransactionWithoutSharedPosting()],
            ledgerSettings: try makeLedgerSettings()
        )

        #expect(result.errors.isEmpty)
        #expect(result.transactions.count == 1)
        #expect(result.sheetCells == [
            ["Date", "Description", "Payee", "Category", "Payor", "Share Other Person"],
            ["2025-01-01", "Weekly shop", "Store", "Groceries", "Alice", "30.63"]
        ])
    }

    @Test
    func buildUploadSheetCellsUsesOwnerAsPayorWhenSharedPostingIsPositive() throws {
        let syncer = TestSyncer(sheetURL: "", ledger: Ledger())
        let data = [
            ["Date", "Description", "Payee", "Category", "Payor", "Share Other Person", "Running Total"],
            ["2025-01-01", "Existing row", "Store", "Groceries", "Bob", "30.63", "30.63"]
        ]
        let parsed = SheetParser.parseSheetData(data, name: "Alice")
        let result = try SheetCellsFormatter.buildUploadSheetCells(
            syncer: syncer,
            layout: parsed.layout,
            transactions: [try ownerPaidTransactionWithoutOwnPosting()],
            ledgerSettings: try makeLedgerSettings()
        )

        #expect(result.errors.isEmpty)
        #expect(result.transactions.count == 1)
        #expect(result.sheetCells == [
            ["Date", "Description", "Payee", "Category", "Payor", "Share Other Person"],
            ["2025-01-01", "Weekly shop", "Store", "Groceries", "Alice", "30.63"]
        ])
    }

    @Test
    func buildUploadSheetCellsUsesOwnerAsPayorForOrdinaryCardPayment() throws {
        let syncer = TestSyncer(sheetURL: "", ledger: Ledger())
        let data = [
            ["Date", "Description", "Payee", "Category", "Payor", "Share Other Person", "Running Total"],
            ["2025-01-01", "Existing row", "Store", "", "Bob", "1.00", "1.00"]
        ]
        let parsed = SheetParser.parseSheetData(data, name: "Alice")
        let ledgerSettings = LedgerSettings(
            commoditySymbol: "CAD",
            tag: Tag(name: "shared"),
            name: "Alice",
            accountName: try AccountName("Assets:Shared"),
            dateTolerance: 86_400,
            categoryAccountNames: ["Parking": try AccountName("Expenses:Transportation:Car:Parking")],
            accountNameCategories: ["Expenses:Transportation:Car:Parking": "Parking"]
        )
        let result = try SheetCellsFormatter.buildUploadSheetCells(
            syncer: syncer,
            layout: parsed.layout,
            transactions: [try ownerPaidCardTransactionWithoutSyncPostings()],
            ledgerSettings: ledgerSettings
        )

        #expect(result.errors.isEmpty)
        #expect(result.transactions.count == 1)
        #expect(result.sheetCells == [
            ["Date", "Description", "Payee", "Category", "Payor", "Share Other Person"],
            ["2025-05-15", "PayByPhone - Fountainhead Ash", "City of Vancouver", "Parking", "Alice", "1.00"]
        ])
    }

    @Test
    func buildUploadSheetCellsFailsWithoutLayout() {
        let syncer = TestSyncer(sheetURL: "", ledger: Ledger())
        do {
            _ = try SheetCellsFormatter.buildUploadSheetCells(
                syncer: syncer,
                layout: nil,
                transactions: [try ownerPaidTransaction()],
                ledgerSettings: try makeLedgerSettings()
            )
            Issue.record("Expected failure")
        } catch let error as SyncError {
            #expect(error == .missingSheetLayout)
        } catch {
            Issue.record("Expected SyncError, got \(error)")
        }
    }

    @Test
    func buildUploadSheetCellsCollectsRowErrorsAndFormatsOtherRows() throws {
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
            transactions: [try ownerPaidTransaction(), try otherPaidTransaction()],
            ledgerSettings: try makeLedgerSettings()
        )

        #expect(result.transactions.count == 1)
        #expect(result.sheetCells == [
            ["Date", "Payee", "Amount", "Category", "Payor", "Description"],
            ["2025-01-01", "Store", "61.26", "Groceries", "Alice", "Weekly shop"]
        ])
        #expect(result.errors == [
            .invalidValue(
                "Upload transaction 2025-01-01 Store failed: Unable to format transaction for the sheet: " +
                "Cannot derive the total amount for a total-amount sheet when the owner did not pay"
            )
        ])
    }

}
#endif
