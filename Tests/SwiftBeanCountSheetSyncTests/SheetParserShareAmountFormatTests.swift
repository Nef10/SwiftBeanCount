import Foundation
@testable import SwiftBeanCountSheetSync
import Testing

@Suite
struct SheetParserShareAmountFormatTests {

    @Test
    func parseSheetShareAmountFormatWithValidData() {
        // Mirrors the sample data from the user's request
        let data = [
            ["Date", "Payor", "Payee", "Description", "Category", "Share Other Person", "Alice ows Bob", "Running Total"],
            ["2025-01-01", "Bob", "Olympia", "Lunch after Polar Bear Swim", "", "CA$15.34", "CA$15.34", "CA$15.34"],
            ["2025-01-10", "Bob", "Cineplex", "Wicked", "", "CA$4.96", "CA$4.96", "CA$20.30"],
            ["2025-01-13", "Alice", "Western Lake", "Lunch Suyang + Paul", "", "CA$30.63", "-CA$30.63", "-CA$10.33"],
            ["2025-01-13", "Bob", "Commercial Street Cafe", "Hot Chocolate", "", "CA$4.75", "CA$4.75", "-CA$5.58"]
        ]

        let parsed = SheetParser.parseSheetData(data, name: "Alice")
        let transactions = parsed.rows.map(\.transactionData)
        let errors = parsed.errors

        #expect(errors.isEmpty)
        #expect(transactions.count == 4)

        // Bob paid at Olympia: Alice owes CA$15.34 (payer == .two)
        let olympia = transactions.first { $0.payee == "Olympia" }!
        #expect(olympia.paidBy == .two)
        #expect(olympia.narration == "Lunch after Polar Bear Swim")
        #expect(olympia.amount1 == Decimal(string: "15.34"))

        // Alice paid at Western Lake: equal split from CA$30.63 (payer == .one)
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

        let transactions = SheetParser.parseSheetData(data, name: "Alice").rows.map(\.transactionData)

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

        let transactions = SheetParser.parseSheetData(data, name: "Alice").rows.map(\.transactionData)

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
            ["2025-02-01", "Bob", "Store", "Shopping", "", "CA$30.63", "CA$30.63"],
            ["2025-02-05", "Alice", "Restaurant", "Dinner", "", "CA$20.00", "-CA$9.37"]
        ]

        let parsed = SheetParser.parseSheetData(data, name: "Alice")
        let transactions = parsed.rows.map(\.transactionData)
        let runningTotal = parsed.runningTotal

        #expect(transactions.count == 2)
        let bob = transactions.first { $0.payee == "Store" }!
        #expect(bob.amount1 == Decimal(string: "30.63"))

        let alice = transactions.first { $0.payee == "Restaurant" }!
        #expect(alice.amount1 == Decimal(string: "20.00"))
        #expect(alice.amount == Decimal(string: "40.00"))

        // Running total from last row: -CA$9.37
        #expect(runningTotal == Decimal(string: "-9.37"))
    }

    @Test
    func parseSheetShareAmountFormatReturnsRunningTotal() {
        let data = [
            ["Date", "Payor", "Payee", "Description", "Category", "Share Other Person", "Running Total"],
            ["2025-01-01", "Bob", "Store A", "First", "", "CA$10.00", "CA$10.00"],
            ["2025-01-15", "Bob", "Store B", "Second", "", "CA$5.00", "CA$15.00"]
        ]

        let runningTotal = SheetParser.parseSheetData(data, name: "Alice").runningTotal

        #expect(runningTotal == Decimal(string: "15.00"))
    }

    @Test
    func parseSheetShareAmountFormatNegativeRunningTotal() {
        let data = [
            ["Date", "Payor", "Payee", "Description", "Category", "Share Other Person", "Running Total"],
            ["2025-01-01", "Bob", "Store A", "First", "", "CA$10.00", "CA$10.00"],
            ["2025-01-05", "Alice", "Store B", "Second", "", "CA$30.00", "-CA$20.00"]
        ]

        let runningTotal = SheetParser.parseSheetData(data, name: "Alice").runningTotal

        #expect(runningTotal == Decimal(string: "-20.00"))
    }

    @Test
    func parseSheetShareAmountFormatMissingRequiredHeader() {
        // Missing "Share Other Person" triggers old-format path which then fails on missing payer col
        // Providing "Share Other Person" but missing "Date" triggers new-format missing-header error
        let data = [
            ["Payor", "Payee", "Description", "Category", "Share Other Person", "Running Total"],
            ["Bob", "Store", "Test", "", "CA$10.00", "CA$10.00"]
        ]

        let errors = SheetParser.parseSheetData(data, name: "Alice").errors

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
            ["2025-01-01", "Bob", "Olympia", "Lunch", "", "CA$15.00", "CA$15.00"]
        ]

        let transactions = SheetParser.parseSheetData(data, name: "Alice").rows.map(\.transactionData)

        #expect(transactions.count == 1)
        #expect(transactions[0].payee == "Olympia")
    }

    @Test
    func parseSheetShareAmountFormatWithAlternativePayorColumnName() {
        let data = [
            ["Date", "Who paid", "Payee", "Description", "Category", "Share Other Person", "Running Total"],
            ["2025-01-01", "Alice", "Store", "Test", "", "CA$20.00", "-CA$20.00"]
        ]

        let transactions = SheetParser.parseSheetData(data, name: "Alice").rows.map(\.transactionData)

        #expect(transactions.count == 1)
        #expect(transactions[0].paidBy == .one)
    }

    @Test
    func parseSheetShareAmountFormatWithAlternativeNarrationColumnName() {
        let data = [
            ["Date", "Payor", "Payee", "Comment", "Category", "Share Other Person", "Running Total"],
            ["2025-01-01", "Bob", "Store", "Test note", "", "CA$10.00", "CA$10.00"]
        ]

        let transactions = SheetParser.parseSheetData(data, name: "Alice").rows.map(\.transactionData)

        #expect(transactions.count == 1)
        #expect(transactions[0].narration == "Test note")
    }

    @Test
    func parseSheetShareAmountFormatSortsTransactionsByDate() {
        let data = [
            ["Date", "Payor", "Payee", "Description", "Category", "Share Other Person", "Running Total"],
            ["2025-03-10", "Bob", "StoreB", "Later", "", "CA$5.00", "CA$15.00"],
            ["2025-03-01", "Bob", "StoreA", "Earlier", "", "CA$10.00", "CA$10.00"]
        ]

        let transactions = SheetParser.parseSheetData(data, name: "Alice").rows.map(\.transactionData)

        #expect(transactions.count == 2)
        #expect(transactions[0].payee == "StoreA")
        #expect(transactions[1].payee == "StoreB")
    }

    @Test
    func parseSheetShareAmountFormatInvalidShareOtherPersonAmount() {
        let data = [
            ["Date", "Payor", "Payee", "Description", "Category", "Share Other Person", "Running Total"],
            ["2025-01-01", "Bob", "Store", "Test", "", "invalid", "CA$0.00"]
        ]

        let errors = SheetParser.parseSheetData(data, name: "Alice").errors

        #expect(errors.count == 1)
        #expect(errors[0] == .invalidValue("Line 2: Parsing Error! Invalid Number: invalid"))
    }

    @Test
    func parseSheetShareAmountFormatTrimsWhitespaceFromTextFields() {
        let data = [
            ["Date", "Payor", "Payee", "Description", "Category", "Share Other Person"],
            [" 2025-01-01 ", " Bob ", " Store ", " Lunch ", " Food ", " CA$30.00 "],
            ["2025-01-02", " Alice ", "Cinema", "Movie", "Fun", "CA$10.00"]
        ]

        let transactions = SheetParser.parseSheetData(data, name: "Alice").rows.map(\.transactionData)

        #expect(transactions.count == 2)
        #expect(transactions[0].payee == "Store")
        #expect(transactions[0].narration == "Lunch")
        #expect(transactions[0].category == "Food")
        #expect(transactions[0].paidBy == .two)
        #expect(transactions[1].paidBy == .one)
    }

    private func parseRunningTotal(_ data: [[String]], name: String = "Alice", negateRunningTotal: Bool = false) -> Decimal? {
        SheetParser.parseSheetData(data, name: name, negateRunningTotal: negateRunningTotal).runningTotal
    }

    @Test
    func parseSheetRunningTotalNegatedWhenFlagIsTrue() {
        let data = [
            ["Date", "Payor", "Payee", "Description", "Category", "Share Other Person", "Running Total"],
            ["2025-01-01", "Bob", "Store", "Test", "", "CA$36.75", "CA$36.75"]
        ]
        #expect(parseRunningTotal(data, negateRunningTotal: true) == Decimal(string: "-36.75"))
    }

    @Test
    func parseSheetRunningTotalNotNegatedWhenFlagIsFalse() {
        let data = [
            ["Date", "Payor", "Payee", "Description", "Category", "Share Other Person", "Running Total"],
            ["2025-01-01", "Bob", "Store", "Test", "", "CA$36.75", "CA$36.75"]
        ]
        #expect(parseRunningTotal(data, negateRunningTotal: false) == Decimal(string: "36.75"))
    }

    @Test
    func parseSheetRunningTotalNegatesNegativeCellValueCorrectly() {
        // negateRunningTotal: true applied to a negative cell value → positive result
        let data = [
            ["Date", "Payor", "Payee", "Description", "Category", "Share Other Person", "Running Total"],
            ["2025-01-01", "Alice", "Store", "Test", "", "CA$36.75", "-CA$36.75"]
        ]
        #expect(parseRunningTotal(data, negateRunningTotal: true) == Decimal(string: "36.75"))
    }

    @Test
    func parseSheetRunningTotalDefaultsToNotNegating() {
        let data = [
            ["Date", "Payor", "Payee", "Description", "Category", "Share Other Person", "Running Total"],
            ["2025-01-01", "Bob", "Store", "Test", "", "CA$36.75", "CA$36.75"]
        ]
        #expect(parseRunningTotal(data) == Decimal(string: "36.75"))
    }
}
