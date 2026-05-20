import Foundation
@testable import SwiftBeanCountSheetSync
import Testing

@Suite
struct SheetParserShareAmountFormatTests {

    @Test
    func parseSheetShareAmountFormatWithValidData() {
        // Mirrors the sample data from the user's request
        let data = [
            ["Date", "Payor", "Payee", "Description", "Category", "Share Other Person", "Steffen ows Hanbo", "Running Total"],
            ["2025-01-01", "Hanbo", "Olympia", "Lunch after Polar Bear Swim", "", "CA$15.34", "CA$15.34", "CA$15.34"],
            ["2025-01-10", "Hanbo", "Cineplex", "Wicked", "", "CA$4.96", "CA$4.96", "CA$20.30"],
            ["2025-01-13", "Steffen", "Western Lake", "Lunch Suyang + Paul", "", "CA$30.63", "-CA$30.63", "-CA$10.33"],
            ["2025-01-13", "Hanbo", "Commercial Street Cafe", "Hot Chocolate", "", "CA$4.75", "CA$4.75", "-CA$5.58"]
        ]

        var transactions: [SheetParser.TransactionData]!
        var errors: [SheetParserError]!
        SheetParser.parseSheet(data, name: "Steffen") { parsedTransactions, _, parsedErrors in
            transactions = parsedTransactions
            errors = parsedErrors
        }

        #expect(errors.isEmpty)
        #expect(transactions.count == 4)

        // Hanbo paid at Olympia: Steffen owes CA$15.34 (payer == .two)
        let olympia = transactions.first { $0.payee == "Olympia" }!
        #expect(olympia.paidBy == .two)
        #expect(olympia.narration == "Lunch after Polar Bear Swim")
        #expect(olympia.amount1 == Decimal(string: "15.34"))

        // Steffen paid at Western Lake: equal split from CA$30.63 (payer == .one)
        let westernLake = transactions.first { $0.payee == "Western Lake" }!
        #expect(westernLake.paidBy == .one)
        #expect(westernLake.amount1 == Decimal(string: "30.63"))
        #expect(westernLake.amount2 == Decimal(string: "30.63"))
        #expect(westernLake.amount == Decimal(string: "61.26"))
    }

    @Test
    func parseSheetShareAmountFormatEqualSplitAmounts() {
        let data = [
            ["Date", "Payor", "Payee", "Description", "Category", "Share Other Person", "Running Total"],
            ["2025-03-01", "Alice", "Supermarket", "Groceries", "", "CA$25.00", "CA$25.00"]
        ]

        var transactions: [SheetParser.TransactionData]!
        SheetParser.parseSheet(data, name: "Alice") { parsedTransactions, _, _ in
            transactions = parsedTransactions
        }

        #expect(transactions.count == 1)
        let transaction = transactions[0]
        // Alice paid; equal-split assumption: amount = 2 × shareOtherPerson
        #expect(transaction.paidBy == .one)
        #expect(transaction.amount1 == Decimal(string: "25.00"))
        #expect(transaction.amount2 == Decimal(string: "25.00"))
        #expect(transaction.amount == Decimal(string: "50.00"))
    }

    @Test
    func parseSheetShareAmountFormatOtherPersonPaid() {
        let data = [
            ["Date", "Payor", "Payee", "Description", "Category", "Share Other Person", "Running Total"],
            ["2025-03-01", "Bob", "Cinema", "Movie", "", "CA$12.00", "CA$12.00"]
        ]

        var transactions: [SheetParser.TransactionData]!
        SheetParser.parseSheet(data, name: "Alice") { parsedTransactions, _, _ in
            transactions = parsedTransactions
        }

        #expect(transactions.count == 1)
        let transaction = transactions[0]
        // Bob paid; Alice owes her share
        #expect(transaction.paidBy == .two)
        #expect(transaction.amount1 == Decimal(string: "12.00"))
        #expect(transaction.amount2 == 0)
        #expect(transaction.amount == 0)
    }

    @Test
    func parseSheetShareAmountFormatCurrencyPrefixedAmounts() {
        let data = [
            ["Date", "Payor", "Payee", "Description", "Category", "Share Other Person", "Running Total"],
            ["2025-02-01", "Hanbo", "Store", "Shopping", "", "CA$30.63", "CA$30.63"],
            ["2025-02-05", "Steffen", "Restaurant", "Dinner", "", "CA$20.00", "-CA$9.37"]
        ]

        var transactions: [SheetParser.TransactionData]!
        var runningTotal: Decimal?
        SheetParser.parseSheet(data, name: "Steffen") { parsedTransactions, parsedRunningTotal, _ in
            transactions = parsedTransactions
            runningTotal = parsedRunningTotal
        }

        #expect(transactions.count == 2)
        let hanbo = transactions.first { $0.payee == "Store" }!
        #expect(hanbo.amount1 == Decimal(string: "30.63"))

        let steffen = transactions.first { $0.payee == "Restaurant" }!
        #expect(steffen.amount1 == Decimal(string: "20.00"))
        #expect(steffen.amount == Decimal(string: "40.00"))

        // Running total from last row: -CA$9.37
        #expect(runningTotal == Decimal(string: "-9.37"))
    }

    @Test
    func parseSheetShareAmountFormatReturnsRunningTotal() {
        let data = [
            ["Date", "Payor", "Payee", "Description", "Category", "Share Other Person", "Running Total"],
            ["2025-01-01", "Hanbo", "Store A", "First", "", "CA$10.00", "CA$10.00"],
            ["2025-01-15", "Hanbo", "Store B", "Second", "", "CA$5.00", "CA$15.00"]
        ]

        var runningTotal: Decimal?
        SheetParser.parseSheet(data, name: "Steffen") { _, parsedRunningTotal, _ in
            runningTotal = parsedRunningTotal
        }

        #expect(runningTotal == Decimal(string: "15.00"))
    }

    @Test
    func parseSheetShareAmountFormatNegativeRunningTotal() {
        let data = [
            ["Date", "Payor", "Payee", "Description", "Category", "Share Other Person", "Running Total"],
            ["2025-01-01", "Hanbo", "Store A", "First", "", "CA$10.00", "CA$10.00"],
            ["2025-01-05", "Steffen", "Store B", "Second", "", "CA$30.00", "-CA$20.00"]
        ]

        var runningTotal: Decimal?
        SheetParser.parseSheet(data, name: "Steffen") { _, parsedRunningTotal, _ in
            runningTotal = parsedRunningTotal
        }

        #expect(runningTotal == Decimal(string: "-20.00"))
    }

    @Test
    func parseSheetShareAmountFormatMissingRequiredHeader() {
        // Missing "Share Other Person" triggers old-format path which then fails on missing payer col
        // Providing "Share Other Person" but missing "Date" triggers new-format missing-header error
        let data = [
            ["Payor", "Payee", "Description", "Category", "Share Other Person", "Running Total"],
            ["Hanbo", "Store", "Test", "", "CA$10.00", "CA$10.00"]
        ]

        var errors: [SheetParserError]!
        SheetParser.parseSheet(data, name: "Steffen") { _, _, parsedErrors in
            errors = parsedErrors
        }

        #expect(errors.count == 1)
        if case .missingHeader = errors[0] {
            // expected
        } else {
            Issue.record("Expected missingHeader error, got \(errors[0])")
        }
    }

    @Test
    func parseSheetShareAmountFormatWithAlternativePayeeColumnName() {
        let data = [
            ["Date", "Payor", "Paid to", "Description", "Category", "Share Other Person", "Running Total"],
            ["2025-01-01", "Hanbo", "Olympia", "Lunch", "", "CA$15.00", "CA$15.00"]
        ]

        var transactions: [SheetParser.TransactionData]!
        SheetParser.parseSheet(data, name: "Steffen") { parsedTransactions, _, _ in
            transactions = parsedTransactions
        }

        #expect(transactions.count == 1)
        #expect(transactions[0].payee == "Olympia")
    }

    @Test
    func parseSheetShareAmountFormatWithAlternativePayorColumnName() {
        let data = [
            ["Date", "Who paid", "Payee", "Description", "Category", "Share Other Person", "Running Total"],
            ["2025-01-01", "Steffen", "Store", "Test", "", "CA$20.00", "-CA$20.00"]
        ]

        var transactions: [SheetParser.TransactionData]!
        SheetParser.parseSheet(data, name: "Steffen") { parsedTransactions, _, _ in
            transactions = parsedTransactions
        }

        #expect(transactions.count == 1)
        #expect(transactions[0].paidBy == .one)
    }

    @Test
    func parseSheetShareAmountFormatWithAlternativeNarrationColumnName() {
        let data = [
            ["Date", "Payor", "Payee", "Comment", "Category", "Share Other Person", "Running Total"],
            ["2025-01-01", "Hanbo", "Store", "Test note", "", "CA$10.00", "CA$10.00"]
        ]

        var transactions: [SheetParser.TransactionData]!
        SheetParser.parseSheet(data, name: "Steffen") { parsedTransactions, _, _ in
            transactions = parsedTransactions
        }

        #expect(transactions.count == 1)
        #expect(transactions[0].narration == "Test note")
    }

    @Test
    func parseSheetShareAmountFormatSortsTransactionsByDate() {
        let data = [
            ["Date", "Payor", "Payee", "Description", "Category", "Share Other Person", "Running Total"],
            ["2025-03-10", "Hanbo", "StoreB", "Later", "", "CA$5.00", "CA$15.00"],
            ["2025-03-01", "Hanbo", "StoreA", "Earlier", "", "CA$10.00", "CA$10.00"]
        ]

        var transactions: [SheetParser.TransactionData]!
        SheetParser.parseSheet(data, name: "Steffen") { parsedTransactions, _, _ in
            transactions = parsedTransactions
        }

        #expect(transactions.count == 2)
        #expect(transactions[0].payee == "StoreA")
        #expect(transactions[1].payee == "StoreB")
    }

    @Test
    func parseSheetShareAmountFormatInvalidShareOtherPersonAmount() {
        let data = [
            ["Date", "Payor", "Payee", "Description", "Category", "Share Other Person", "Running Total"],
            ["2025-01-01", "Hanbo", "Store", "Test", "", "invalid", "CA$0.00"]
        ]

        var errors: [SheetParserError]!
        SheetParser.parseSheet(data, name: "Steffen") { _, _, parsedErrors in
            errors = parsedErrors
        }

        #expect(errors.count == 1)
        #expect(errors[0] == .invalidValue("Parsing Error! Invalid Number: invalid"))
    }
}
