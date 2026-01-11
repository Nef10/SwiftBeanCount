import Foundation
import SwiftBeanCountModel
@testable import SwiftBeanCountSheetSync
import Testing

@Suite
struct TransactionMapperTests {

    private func createLedgerSettings(
        commoditySymbol: String = "USD",
        tagName: String = "shared",
        name: String = "Alice",
        accountName: String = "Assets:Shared",
        categoryMapping: [String: String] = [:]
    ) throws -> LedgerSettings {
        let categoryAccountNames = try categoryMapping.reduce(into: [String: AccountName]()) { result, pair in
            result[pair.key] = try AccountName(pair.value)
        }
        let accountNameCategories = Dictionary(categoryAccountNames.map { ($0.value.fullName, $0.key) }) { first, _ in first }

        return LedgerSettings(
            commoditySymbol: commoditySymbol,
            tag: Tag(name: tagName),
            name: name,
            accountName: try AccountName(accountName),
            dateTolerance: 86_400,
            categoryAccountNames: categoryAccountNames,
            accountNameCategories: accountNameCategories
        )
    }

    @Test
    func mapDataToTransactionsWithPayerOne() throws {
        let date = Date(timeIntervalSince1970: 1_705_276_800) // 2024-01-15
        let transactionData = SheetParser.TransactionData(
            date: date,
            payee: "Store",
            narration: "Weekly shopping",
            category: "Groceries",
            amount: Decimal(string: "100.00")!,
            amount1: Decimal(string: "50.00")!,
            amount2: Decimal(string: "50.00")!,
            paidBy: .one
        )

        let ledgerSettings = try createLedgerSettings(categoryMapping: ["Groceries": "Expenses:Groceries"])
        let transactions = TransactionMapper.mapDataToTransactions([transactionData], ledgerSettings: ledgerSettings)

        #expect(transactions.count == 1)
        let transaction = transactions[0]
        #expect(transaction.metaData.payee == "Store")
        #expect(transaction.metaData.narration == "Weekly shopping")
        #expect(transaction.metaData.date == date)
        #expect(transaction.metaData.tags.contains(Tag(name: "shared")))
        #expect(transaction.postings.count == 3)

        let expensePosting = transaction.postings.first { $0.accountName.fullName == "Expenses:Groceries" }
        #expect(expensePosting != nil)
        #expect(expensePosting?.amount.number == Decimal(string: "50.00")!)
        #expect(expensePosting?.amount.commoditySymbol == "USD")

        let ownPosting = transaction.postings.first { $0.accountName == LedgerSettings.ownAccountName }
        #expect(ownPosting != nil)
        #expect(ownPosting?.amount.number == Decimal(string: "-100.00")!)
    }

    @Test
    func mapDataToTransactionsWithPayerTwo() throws {
        let date = Date(timeIntervalSince1970: 1_705_276_800)
        let transactionData = SheetParser.TransactionData(
            date: date,
            payee: "Restaurant",
            narration: "Dinner",
            category: "Dining",
            amount: Decimal(string: "80.00")!,
            amount1: Decimal(string: "40.00")!,
            amount2: Decimal(string: "40.00")!,
            paidBy: .two
        )

        let ledgerSettings = try createLedgerSettings(
            commoditySymbol: "CAD",
            tagName: "joint",
            accountName: "Assets:Joint",
            categoryMapping: ["Dining": "Expenses:Dining"]
        )
        let transactions = TransactionMapper.mapDataToTransactions([transactionData], ledgerSettings: ledgerSettings)

        #expect(transactions.count == 1)
        let transaction = transactions[0]
        #expect(transaction.postings.count == 2)

        let expensePosting = transaction.postings.first { $0.accountName.fullName == "Expenses:Dining" }
        #expect(expensePosting != nil)
        #expect(expensePosting?.amount.number == Decimal(string: "40.00")!)
        #expect(expensePosting?.amount.commoditySymbol == "CAD")

        let sharedPosting = transaction.postings.first { $0.accountName.fullName == "Assets:Joint" }
        #expect(sharedPosting != nil)
        #expect(sharedPosting?.amount.number == Decimal(string: "-40.00")!)
    }

    @Test
    func mapDataToTransactionsWithFallbackAccount() throws {
        let date = Date(timeIntervalSince1970: 1_705_276_800)
        let transactionData = SheetParser.TransactionData(
            date: date,
            payee: "Unknown",
            narration: "Mystery expense",
            category: "UnknownCategory",
            amount: Decimal(string: "25.00")!,
            amount1: Decimal(string: "12.50")!,
            amount2: Decimal(string: "12.50")!,
            paidBy: .one
        )

        let ledgerSettings = try createLedgerSettings(commoditySymbol: "EUR", tagName: "test")
        let transactions = TransactionMapper.mapDataToTransactions([transactionData], ledgerSettings: ledgerSettings)

        #expect(transactions.count == 1)
        let transaction = transactions[0]
        #expect(transaction.postings.contains { $0.accountName == LedgerSettings.fallbackAccountName })
    }

    @Test
    func mapMultipleTransactions() throws {
        let date1 = Date(timeIntervalSince1970: 1_705_276_800)
        let date2 = Date(timeIntervalSince1970: 1_705_363_200)

        let data = [
            SheetParser.TransactionData(
                date: date1,
                payee: "Store1",
                narration: "Shopping",
                category: "Groceries",
                amount: Decimal(string: "100.00")!,
                amount1: Decimal(string: "50.00")!,
                amount2: Decimal(string: "50.00")!,
                paidBy: .one
            ),
            SheetParser.TransactionData(
                date: date2,
                payee: "Store2",
                narration: "More shopping",
                category: "Groceries",
                amount: Decimal(string: "150.00")!,
                amount1: Decimal(string: "75.00")!,
                amount2: Decimal(string: "75.00")!,
                paidBy: .two
            )
        ]

        let ledgerSettings = try createLedgerSettings()
        let transactions = TransactionMapper.mapDataToTransactions(data, ledgerSettings: ledgerSettings)

        #expect(transactions.count == 2)
        #expect(transactions[0].metaData.payee == "Store1")
        #expect(transactions[1].metaData.payee == "Store2")
    }
}
