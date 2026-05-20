import Foundation
@testable import SwiftBeanCountSheetSync
import Testing

// Tests that verify every number format documented in "Supported Number Formats"
// and all combinations of sign notation, currency prefix, and thousands separator.
@Suite
struct SheetParserNumberFormatTests {

    // MARK: - Currency symbol

    @Test
    func parseSheetAmountsWithCurrencySymbolOnly() {
        let data = [
            ["Date", "Paid to", "Amount", "Category", "Who paid", "Comment", "Part Alice", "Part Bob"],
            ["2024-01-15", "A", "$30.63", "G", "Alice", "N", "$15.00", "$15.63"],
            ["2024-01-16", "B", "$1,030.63", "G", "Bob", "N", "$515.00", "$515.63"],
            ["2024-01-17", "C", "CA$1,030.63", "G", "Alice", "N", "CA$500.00", "CA$530.63"]
        ]
        var transactions: [SheetParser.TransactionData]!
        SheetParser.parseSheet(data, name: "Alice") { parsedTransactions, _, _ in
            transactions = parsedTransactions
        }
        #expect(transactions.count == 3)
        #expect(transactions[0].amount == Decimal(string: "30.63"))
        #expect(transactions[0].amount1 == Decimal(string: "15.00"))
        #expect(transactions[0].amount2 == Decimal(string: "15.63"))
        #expect(transactions[1].amount == Decimal(string: "1030.63"))
        #expect(transactions[1].amount1 == Decimal(string: "515.00"))
        #expect(transactions[2].amount == Decimal(string: "1030.63"))
    }

    // MARK: - Leading minus

    @Test
    func parseSheetAmountsWithLeadingMinus() {
        let data = [
            ["Date", "Paid to", "Amount", "Category", "Who paid", "Comment", "Part Alice", "Part Bob"],
            ["2024-01-15", "A", "-30.63", "G", "Alice", "N", "-15.00", "-15.63"],
            ["2024-01-16", "B", "-$30.63", "G", "Bob", "N", "-15.00", "-15.63"],
            ["2024-01-17", "C", "-CA$30.63", "G", "Alice", "N", "-15.00", "-15.63"]
        ]
        var transactions: [SheetParser.TransactionData]!
        SheetParser.parseSheet(data, name: "Alice") { parsedTransactions, _, _ in
            transactions = parsedTransactions
        }
        #expect(transactions.count == 3)
        #expect(transactions[0].amount == Decimal(string: "-30.63"))
        #expect(transactions[1].amount == Decimal(string: "-30.63"))
        #expect(transactions[1].amount1 == Decimal(string: "-15.00"))
        #expect(transactions[2].amount == Decimal(string: "-30.63"))
    }

    @Test
    func parseSheetAmountsWithLeadingMinusAndThousands() {
        let data = [
            ["Date", "Paid to", "Amount", "Category", "Who paid", "Comment", "Part Alice", "Part Bob"],
            ["2024-01-15", "A", "-1,030.63", "G", "Alice", "N", "-500.00", "-530.63"],
            ["2024-01-16", "B", "-$1,030.63", "G", "Bob", "N", "-500.00", "-530.63"],
            ["2024-01-17", "C", "-CA$1,030.63", "G", "Alice", "N", "-500.00", "-530.63"]
        ]
        var transactions: [SheetParser.TransactionData]!
        SheetParser.parseSheet(data, name: "Alice") { parsedTransactions, _, _ in
            transactions = parsedTransactions
        }
        #expect(transactions.count == 3)
        #expect(transactions[0].amount == Decimal(string: "-1030.63"))
        #expect(transactions[1].amount == Decimal(string: "-1030.63"))
        #expect(transactions[2].amount == Decimal(string: "-1030.63"))
        #expect(transactions[2].amount1 == Decimal(string: "-500.00"))
    }

    // MARK: - Accounting negative

    @Test
    func parseSheetAmountsWithAccountingNegativeAndCurrency() {
        let data = [
            ["Date", "Paid to", "Amount", "Category", "Who paid", "Comment", "Part Alice", "Part Bob"],
            ["2024-01-15", "A", "($30.63)", "G", "Alice", "N", "($15.00)", "($15.63)"],
            ["2024-01-16", "B", "(CA$30.63)", "G", "Bob", "N", "(CA$15.00)", "(CA$15.63)"]
        ]
        var transactions: [SheetParser.TransactionData]!
        SheetParser.parseSheet(data, name: "Alice") { parsedTransactions, _, _ in
            transactions = parsedTransactions
        }
        #expect(transactions.count == 2)
        #expect(transactions[0].amount == Decimal(string: "-30.63"))
        #expect(transactions[0].amount1 == Decimal(string: "-15.00"))
        #expect(transactions[0].amount2 == Decimal(string: "-15.63"))
        #expect(transactions[1].amount == Decimal(string: "-30.63"))
        #expect(transactions[1].amount1 == Decimal(string: "-15.00"))
    }

    @Test
    func parseSheetAmountsWithAccountingNegativeAndThousands() {
        let data = [
            ["Date", "Paid to", "Amount", "Category", "Who paid", "Comment", "Part Alice", "Part Bob"],
            ["2024-01-15", "A", "(1,030.63)", "G", "Alice", "N", "(500.00)", "(530.63)"],
            ["2024-01-16", "B", "($1,030.63)", "G", "Bob", "N", "($500.00)", "($530.63)"],
            ["2024-01-17", "C", "(CA$1,030.63)", "G", "Alice", "N", "(CA$500.00)", "(CA$530.63)"]
        ]
        var transactions: [SheetParser.TransactionData]!
        SheetParser.parseSheet(data, name: "Alice") { parsedTransactions, _, _ in
            transactions = parsedTransactions
        }
        #expect(transactions.count == 3)
        #expect(transactions[0].amount == Decimal(string: "-1030.63"))
        #expect(transactions[1].amount == Decimal(string: "-1030.63"))
        #expect(transactions[1].amount1 == Decimal(string: "-500.00"))
        #expect(transactions[2].amount == Decimal(string: "-1030.63"))
    }

}
