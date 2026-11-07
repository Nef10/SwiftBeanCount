#if RustLedger
import Foundation
import SwiftBeanCountModel
@testable import SwiftBeanCountParser
@testable import SwiftBeanCountRustLedger
import Testing

@Suite
struct RustLedgerParserTests {

    @Test
    func fullLoadUsesRustInterpolationAndRetainsExactWeights() throws {
        guard let expectedMissingUnits = Decimal(string: "-1250.000000000000000001", locale: Locale(identifier: "en_US_POSIX")) else {
            Issue.record("The expected exact decimal literal must parse.")
            return
        }
        let source = """
        2024-01-01 open Assets:Cash USD
        2024-01-01 open Income:Salary USD
        2024-01-02 * "Salary"
          Assets:Cash  1250.000000000000000001 USD
          Income:Salary
        """

        let ledger = Parser.parse(string: source)
        #expect(ledger.transactions.count == 1)
        #expect(ledger.transactions[0].postings.count == 2)
        #expect(ledger.transactions[0].postings[1].amount.number == expectedMissingUnits)
        #expect(ledger.transactions[0].postings[0].amount.decimalDigits == 18)
        #expect(try ledger.transactions[0].balance(in: ledger).amounts == ["USD": Decimal.zero])
        #expect(ledger.ledgerErrors.isEmpty)
    }

    @Test
    func fullLoadParsesBooleanMetadata() {
        let ledger = Parser.parse(string: """
            2024-01-01 open Assets:Cash USD
            2024-01-01 open Equity:Opening USD
            2024-01-02 * "Metadata"
              approved: TRUE
              Assets:Cash 1 USD
              Equity:Opening -1 USD
            """)
        #expect(ledger.transactions.first?.metaData.metaData["approved"] != nil)
        #expect(ledger.errors.isEmpty)
    }

    @Test
    func parsingEditedRootPublishesANewSnapshot() throws {
        let (rootURL, cleanup) = try includedTransactionCollisionFiles()
        defer { cleanup() }
        let ledger = try Parser.parse(contentOf: rootURL)
        guard !ledger.transactions.isEmpty else {
            Issue.record("The included transaction did not load: \(ledger.errors)")
            return
        }
        let rootSource = """
        include "child.beancount"
        2024-01-03 * "Root transaction"
          Assets:Cash 1 USD
          Equity:Offset -1 USD
        """
        try rootSource.write(to: rootURL, atomically: true, encoding: .utf8)
        let updated = try Parser.parse(contentOf: rootURL)
        #expect(ledger.transactions.count == 1)
        #expect(updated.transactions.count == 2)
        #expect(updated.transactions.last?.metaData.narration == "Root transaction")
    }

    @Test
    func implicitAccountsInheritGlobalBookingMethod() {
        let source = """
        option "booking_method" "FIFO"
        2024-01-01 commodity USD
        2024-01-02 * "Implicit accounts"
          Assets:Cash 1 USD
          Equity:Offset -1 USD
        """

        let ledger = Parser.parse(string: source)
        #expect(ledger.accounts.count == 2)
        #expect(ledger.accounts.allSatisfy { $0.bookingMethod == .fifo })
    }

    @Test
    func multilineQuotedEventRetainsWhitespaceAndSourceBytes() {
        let value = "first line\n\t  second line\n\n; literal text"
        let source = "2024-01-01 event \"note\" \"\(value)\"\n"

        let ledger = Parser.parse(string: source)
        #expect(ledger.events.first?.value == value)
        #expect(ledger.retainedSourceDescription == source)
    }

    @Test
    func fileIncludesAreNormalizedBeforeProcessing() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let root = directory.appendingPathComponent("root.bean")
        let child = directory.appendingPathComponent("child.bean")
        let rootSource = "include \"child.bean\"\n"
        let childSource = "2024-01-01 open Assets:Cash USD\n2024-01-01 open Equity:Opening USD\n"
            + "2024-01-02 * \"Included\"\n\tAssets:Cash 1 USD\n\n; comment\n\tEquity:Opening -1 USD\n"
        try rootSource.write(to: root, atomically: true, encoding: .utf8)
        try childSource.write(to: child, atomically: true, encoding: .utf8)

        let ledger = try Parser.parse(contentOf: root)
        let transaction = try #require(ledger.transactions.first)
        #expect(ledger.transactions.count == 1)
        #expect(transaction.postings.count == 2)
        #expect(try transaction.balance(in: ledger).amounts["USD"] == 0)
        #expect(ledger.errors.isEmpty)
        #expect(ledger.retainedSourceDescription == rootSource)
    }

    @Test
    func parsingEditedPluginSourceLeavesPreviousSnapshotUnchanged() {
        let pluginName = "beancount.plugins.check_commodity"
        let configuration = "{\n  'Assets:\"quoted\":.*': 'USD\\d*'\n}"
        let source = """
        plugin "\(pluginName)" \(beancountStringLiteral(configuration))
        2024-01-01 commodity USD
        2024-01-01 open Assets:Cash USD
        2024-01-01 open Equity:Opening USD
        2024-01-02 * "Opening"
          Assets:Cash 1 USD
          Equity:Opening -1 USD
        """

        let ledger = Parser.parse(string: source)
        let updated = Parser.parse(string: source + "\nplugin \"beancount.plugins.implicit_prices\"\n")
        #expect(ledger.errors.isEmpty)
        #expect(ledger.plugins == [pluginName])
        #expect(updated.plugins == [pluginName, "beancount.plugins.implicit_prices"])
        #expect(ledger.description == source)
        #expect(updated.description == source + "\nplugin \"beancount.plugins.implicit_prices\"\n")
    }
}

private func includedTransactionCollisionFiles() throws -> (URL, () -> Void) {
    let fileManager = FileManager.default
    let directory = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
    let rootURL = directory.appendingPathComponent("root.beancount")
    let childURL = directory.appendingPathComponent("child.beancount")
    let rootSource = "include \"child.beancount\"\n"
    let childPadding = ";" + String(repeating: "x", count: 24) + "\n"
    precondition(rootSource.utf8.count == childPadding.utf8.count)
    let childSource = childPadding + """
    2024-01-01 open Assets:Cash USD
    2024-01-01 open Equity:Offset USD
    2024-01-02 * "Same transaction"
      Assets:Cash 1 USD
      Equity:Offset -1 USD
    """
    try rootSource.write(to: rootURL, atomically: true, encoding: .utf8)
    try childSource.write(to: childURL, atomically: true, encoding: .utf8)
    return (rootURL, { _ = try? fileManager.removeItem(at: directory) })
}

private func beancountStringLiteral(_ value: String) -> String {
    "\"" + value
        .replacingOccurrences(of: "\\", with: "\\\\")
        .replacingOccurrences(of: "\"", with: "\\\"")
        .replacingOccurrences(of: "\n", with: "\\n") + "\""
}
#endif
