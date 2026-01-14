import Foundation
@testable import SwiftBeanCountSheetSync
import Testing

@Suite
struct SheetParserErrorTests {

    @Test
    func missingHeaderErrorDescription() {
        let error = SheetParserError.missingHeader("Test header missing")
        #expect(error.localizedDescription == "Test header missing")
    }

    @Test
    func invalidValueErrorDescription() {
        let error = SheetParserError.invalidValue("Invalid value provided")
        #expect(error.localizedDescription == "Invalid value provided")
    }

    @Test
    func missingValueErrorDescription() {
        let error = SheetParserError.missingValue("Value is missing")
        #expect(error.localizedDescription == "Value is missing")
    }
}

@Suite
struct SheetParserTests {

    @Test
    func parseSheetWithValidData() {
        let data = [
            ["Date", "Paid to", "Amount", "Category", "Who paid", "Comment", "Part Alice", "Part Bob"],
            ["2024-01-15", "Store", "100.00", "Groceries", "Alice", "Weekly shopping", "50.00", "50.00"],
            ["2024-01-16", "Restaurant", "80.00", "Dining", "Bob", "Dinner out", "40.00", "40.00"]
        ]

        var transactions: [SheetParser.TransactionData]!
        var errors: [SheetParserError]!
        SheetParser.parseSheet(data, name: "Alice") { parsedTransactions, parsedErrors in
            transactions = parsedTransactions
            errors = parsedErrors
        }

        #expect(transactions.count == 2)
        #expect(errors.isEmpty)

        let transaction = transactions[0]
        #expect(transaction.payee == "Store")
        #expect(transaction.narration == "Weekly shopping")
        #expect(transaction.category == "Groceries")
        #expect(transaction.amount == Decimal(string: "100.00"))
        #expect(transaction.amount1 == Decimal(string: "50.00"))
        #expect(transaction.amount2 == Decimal(string: "50.00"))

        let transaction2 = transactions[1]
        #expect(transaction2.payee == "Restaurant")
        #expect(transaction2.narration == "Dinner out")
        #expect(transaction2.category == "Dining")
        #expect(transaction2.amount == Decimal(string: "80.00"))
        #expect(transaction2.amount1 == Decimal(string: "40.00"))
        #expect(transaction2.amount2 == Decimal(string: "40.00"))
    }

    @Test
    func parseSheetWithEmptyData() {
        let data = [
            ["Date", "Paid to", "Amount", "Category", "Who paid", "Comment", "Part Alice", "Part Bob"]
        ]

        var transactions: [SheetParser.TransactionData]!
        var errors: [SheetParserError]!
        SheetParser.parseSheet(data, name: "Alice") { parsedTransactions, parsedErrors in
            transactions = parsedTransactions
            errors = parsedErrors
        }

        #expect(transactions.isEmpty)
        // Parser requires at least one row to determine payer2, so this will have an error
        #expect(errors.count == 1)
    }

    @Test
    func parseSheetWithMissingHeaders() {
        let data = [
            ["Date", "Amount", "Category"],
            ["2024-01-15", "100.00", "Groceries"]
        ]

        var transactions: [SheetParser.TransactionData]!
        var errors: [SheetParserError]!
        SheetParser.parseSheet(data, name: "Alice") { parsedTransactions, parsedErrors in
            transactions = parsedTransactions
            errors = parsedErrors
        }

        #expect(transactions.isEmpty)
        #expect(errors.count == 1)
        #expect(errors[0] == .missingHeader("Missing Header! Headers: [\"Date\", \"Amount\", \"Category\"]"))
    }

    @Test
    func parseSheetWithInvalidDate() {
        let data = [
            ["Date", "Paid to", "Amount", "Category", "Who paid", "Comment", "Part Alice", "Part Bob"],
            ["invalid-date", "Store", "100.00", "Groceries", "Alice", "Test", "50.00", "50.00"],
            ["2024-01-16", "Restaurant", "80.00", "Dining", "Bob", "Dinner", "40.00", "40.00"]
        ]

        var transactions: [SheetParser.TransactionData]!
        var errors: [SheetParserError]!
        SheetParser.parseSheet(data, name: "Alice") { parsedTransactions, parsedErrors in
            transactions = parsedTransactions
            errors = parsedErrors
        }

        #expect(transactions.count == 1)
        #expect(errors.count == 1)
        #expect(errors[0] == .invalidValue("Parsing Error! Invalid Date: invalid-date"))
    }

    @Test
    func parseSheetWithInvalidAmount() {
        let data = [
            ["Date", "Paid to", "Amount", "Category", "Who paid", "Comment", "Part Alice", "Part Bob"],
            ["2024-01-15", "Store", "invalid", "Groceries", "Alice", "Test", "50.00", "50.00"],
            ["2024-01-16", "Restaurant", "80.00", "Dining", "Bob", "Dinner", "40.00", "40.00"]
        ]

        var transactions: [SheetParser.TransactionData]!
        var errors: [SheetParserError]!
        SheetParser.parseSheet(data, name: "Alice") { parsedTransactions, parsedErrors in
            transactions = parsedTransactions
            errors = parsedErrors
        }

        #expect(transactions.count == 1)
        #expect(errors.count == 1)
        #expect(errors[0] == .invalidValue("Parsing Error! Invalid Number: invalid"))
    }

    @Test
    func parseSheetSortsTransactionsByDate() {
        let data = [
            ["Date", "Paid to", "Amount", "Category", "Who paid", "Comment", "Part Alice", "Part Bob"],
            ["2024-01-20", "Store2", "200.00", "Food", "Bob", "Later", "100.00", "100.00"],
            ["2024-01-15", "Store1", "100.00", "Groceries", "Alice", "Earlier", "50.00", "50.00"]
        ]

        var transactions: [SheetParser.TransactionData]!
        var errors: [SheetParserError]!
        SheetParser.parseSheet(data, name: "Alice") { parsedTransactions, parsedErrors in
            transactions = parsedTransactions
            errors = parsedErrors
        }

        #expect(transactions.count == 2)
        #expect(transactions[0].payee == "Store1")
        #expect(transactions[1].payee == "Store2")
        #expect(errors.isEmpty)
    }

    @Test
    func parseSheetIdentifiesPayer() {
        let data = [
            ["Date", "Paid to", "Amount", "Category", "Who paid", "Comment", "Part Alice", "Part Bob"],
            ["2024-01-15", "Store1", "100.00", "Groceries", "Alice", "Paid by Alice", "50.00", "50.00"],
            ["2024-01-16", "Store2", "200.00", "Food", "Bob", "Paid by Bob", "100.00", "100.00"]
        ]

        var transactions: [SheetParser.TransactionData]!
        var errors: [SheetParserError]!
        SheetParser.parseSheet(data, name: "Alice") { parsedTransactions, parsedErrors in
            transactions = parsedTransactions
            errors = parsedErrors
        }

        #expect(transactions.count == 2)
        #expect(transactions[0].paidBy == .one)
        #expect(transactions[1].paidBy == .two)
        #expect(errors.isEmpty)
    }

    @Test
    func parseSheetRemovesEmptyRows() {
        let data = [
            ["Date", "Paid to", "Amount", "Category", "Who paid", "Comment", "Part Alice", "Part Bob"],
            ["", "", "", "", "", "", "", ""],
            ["2024-01-15", "Store", "100.00", "Groceries", "Alice", "Test", "50.00", "50.00"],
            ["2024-01-16", "Restaurant", "80.00", "Dining", "Bob", "Dinner", "40.00", "40.00"],
            ["-", "-", "-", "-", "-", "-", "-", "-"]
        ]

        var transactions: [SheetParser.TransactionData]!
        var errors: [SheetParserError]!
        SheetParser.parseSheet(data, name: "Alice") { parsedTransactions, parsedErrors in
            transactions = parsedTransactions
            errors = parsedErrors
        }

        #expect(transactions.count == 2)
        #expect(errors.isEmpty)
    }

    @Test
    func parseSheetWithAmountInParentheses() {
        let data = [
            ["Date", "Paid to", "Amount", "Category", "Who paid", "Comment", "Part Alice", "Part Bob"],
            ["2024-01-15", "Store", "(100.00)", "Groceries", "Alice", "Test", "(50.00)", "(50.00)"],
            ["2024-01-16", "Restaurant", "80.00", "Dining", "Bob", "Dinner", "40.00", "40.00"]
        ]

        var transactions: [SheetParser.TransactionData]!
        var errors: [SheetParserError]!
        SheetParser.parseSheet(data, name: "Alice") { parsedTransactions, parsedErrors in
            transactions = parsedTransactions
            errors = parsedErrors
        }

        #expect(transactions.count == 2)
        #expect(errors.isEmpty)

        let transaction = transactions[0]
        #expect(transaction.amount == Decimal(string: "-100.00"))
        #expect(transaction.amount1 == Decimal(string: "-50.00"))
        #expect(transaction.amount2 == Decimal(string: "-50.00"))
    }

    @Test
    func parseSheetWithAmountWithCommas() {
        let data = [
            ["Date", "Paid to", "Amount", "Category", "Who paid", "Comment", "Part Alice", "Part Bob"],
            ["2024-01-15", "Store", "1,234.56", "Groceries", "Alice", "Test", "617.28", "617.28"],
            ["2024-01-16", "Restaurant", "80.00", "Dining", "Bob", "Dinner", "40.00", "40.00"]
        ]

        var transactions: [SheetParser.TransactionData]!
        var errors: [SheetParserError]!
        SheetParser.parseSheet(data, name: "Alice") { parsedTransactions, parsedErrors in
            transactions = parsedTransactions
            errors = parsedErrors
        }

        #expect(transactions.count == 2)
        #expect(errors.isEmpty)

        let transaction = transactions[0]
        #expect(transaction.amount == Decimal(string: "1234.56"))
    }
}
