#if RustLedger
import Foundation
import SwiftBeanCountModel
import SwiftBeanCountParser
import SwiftBeanCountTax
import Testing

@Suite
struct RustLedgerAccountingTests {

    private static let wildcardPurchase = """
    option "inferred_tolerance_default" "*:0.01"
    2024-01-01 open Assets:Cash
    2024-01-01 open Assets:Stock
    2024-01-02 * "Purchase"
      Assets:Cash -135 CAD @ 0.7407 EUR
      Assets:Stock 1 HOOL {100.00 EUR}
    """

    private static let lots = """
    2024-01-01 open Assets:Cash USD
    2024-01-01 open Assets:Stock HOOL "FIFO"
    2024-01-01 open Income:Gains USD
    2024-01-02 * "First lot"
      Assets:Stock 1 HOOL {10 USD}
      Assets:Cash -10 USD
    2024-01-03 * "Second lot"
      Assets:Stock 1 HOOL {20 USD}
      Assets:Cash -20 USD
    2024-01-04 * "Sale"
      Assets:Stock -2 HOOL {} @ 30 USD
      Assets:Cash 60 USD
      Income:Gains
    """

    private static let simple = """
    2024-01-01 open Assets:Cash USD
    2024-01-01 open Equity:Opening USD
    2024-01-02 * "Original"
      Assets:Cash 1.00 USD
      Equity:Opening -1.00 USD
    """

    @Test
    func wildcardToleranceKeepsPermittedExactResidual() throws {
        let ledger = Parser.parse(string: Self.wildcardPurchase)
        let transaction = try #require(ledger.transactions.first)
        let residual = Decimal(string: "0.0055", locale: Locale(identifier: "en_US_POSIX"))
        #expect(try transaction.balance(in: ledger).amounts["EUR"] == residual)
        #expect(ledger.errors.isEmpty)
        #expect(try transaction.balance(in: ledger).amounts["EUR"] == residual)
        #expect(ledger.description == Self.wildcardPurchase)
    }

    @Test
    func fifoSplitPostingsKeepParentAndAuthoredSource() throws {
        let ledger = Parser.parse(string: Self.lots)
        let sale = try #require(ledger.transactions.last)
        let reductions = sale.postings.filter { $0.accountName.fullName == "Assets:Stock" }
        #expect(reductions.count == 2)
        #expect(reductions.allSatisfy { $0.transaction === sale })
        #expect(reductions.compactMap { $0.cost?.amount?.number }.sorted() == [10, 20])
        #expect(try sale.balance(in: ledger).amounts["USD"] == 0)
        #expect(ledger.errors.isEmpty)
        #expect(ledger.description == Self.lots)
    }

    @Test
    func taxSaleUsesEverySplitLotAndExactProceeds() throws {
        let source = Self.lots.replacingOccurrences(
            of: "2024-01-01 open Assets:Stock HOOL \"FIFO\"",
            with: "2024-01-01 open Assets:Stock HOOL \"FIFO\"\n  tax-sale: \"Broker\""
        )
        let ledger = Parser.parse(string: source)
        let sale = try #require(TaxCalculator.getTaxableSales(from: ledger, for: 2_024).first)
        #expect(sale.quantity == 2)
        #expect(sale.proceeds.amounts["USD"] == 60)
        #expect(sale.gain.amounts["USD"] == 30)
        #expect(sale.provider == "Broker")
    }

    @Test
    func civilDatesRemainLocalAcrossDaylightSavingTransitions() throws {
        for (month, day) in [(3, 10), (11, 3)] {
            let source = "2024-\(String(format: "%02d", month))-\(String(format: "%02d", day)) commodity CAD"
            let ledger = Parser.parse(string: source)
            let date = try #require(ledger.commodities.first?.opening)
            let components = Calendar.current.dateComponents([.year, .month, .day, .hour], from: date)
            #expect(components.year == 2_024)
            #expect(components.month == month)
            #expect(components.day == day)
            #expect(components.hour == 0)
        }
    }

    @Test
    func reparsingBackdatedSourceKeepsBothSnapshotsStable() throws {
        let ledger = Parser.parse(string: Self.lots)
        let oldSale = try #require(ledger.transactions.last)
        let updatedSource = Self.lots.replacingOccurrences(
            of: "2024-01-02 * \"First lot\"",
            with: "2024-01-01 * \"Backdated\"\n  Assets:Stock 1 HOOL {5 USD}\n  Assets:Cash -5 USD\n2024-01-02 * \"First lot\""
        )
        let updated = Parser.parse(string: updatedSource)
        let newSale = try #require(updated.transactions.last)
        #expect(newSale !== oldSale)
        let reductions = newSale.postings.filter { $0.accountName.fullName == "Assets:Stock" }
        #expect(reductions.compactMap { $0.cost?.amount?.number }.sorted() == [5, 10])
        #expect(oldSale.postings.compactMap { $0.cost?.amount?.number }.sorted() == [10, 20])
        #expect(ledger.errors.isEmpty)
        #expect(updated.errors.isEmpty)
        #expect(try oldSale.balance(in: ledger).amounts["USD"] == 0)
        #expect(try newSale.balance(in: ledger).amounts["USD"] == 0)
    }

    @Test
    func correctedSourceProducesNewValidSnapshotAndKeepsOldDiagnostics() {
        let invalidSource = Self.simple + "\n2024-01-05 balance Assets:Cash 2.00 USD\n"
        let ledger = Parser.parse(string: invalidSource)
        let correctedSource = invalidSource + "2024-01-03 * \"Correction\"\n  Assets:Cash 1.00 USD\n  Equity:Opening -1.00 USD\n"
        let corrected = Parser.parse(string: correctedSource)
        #expect(!ledger.errors.isEmpty)
        #expect(corrected.errors.isEmpty)
        #expect(ledger.transactions.count == 1)
        #expect(corrected.transactions.count == 2)
    }

    @Test
    func zeroCostAndNegativeTotalPriceUseCanonicalWeights() throws {
        let source = """
        2024-01-01 open Assets:Units
        2024-01-01 open Assets:Cash
        2024-01-02 * "Zero cost"
          Assets:Units 1 TOKEN {0 USD}
          Assets:Cash 0 USD
        2024-01-03 * "Total price"
          Assets:Units -2 TOKEN @@ 20 USD
          Assets:Cash 20 USD
        """
        let ledger = Parser.parse(string: source)
        #expect(ledger.transactions.count == 2)
        for transaction in ledger.transactions {
            #expect(try transaction.balance(in: ledger).amounts["USD"] == 0)
        }
    }

    @Test
    func repeatedSourceEditsCreateIndependentSnapshots() throws {
        let ledger = Parser.parse(string: Self.simple)
        let oldSnapshot = try #require(ledger.transactions.first)
        let first = Parser.parse(string: Self.simple + "\n2024-01-03 * \"First addition\"\n  Assets:Cash 1 USD\n  Equity:Opening -1 USD\n")
        let secondSource = first.description + """
        2024-01-04 * "Second addition"
          Assets:Cash 1 USD
          Equity:Opening -1 USD
        option "title" "Updated"
        """
        let second = Parser.parse(string: secondSource)
        #expect(ledger.transactions.count == 1)
        #expect(first.transactions.count == 2)
        #expect(second.transactions.count == 3)
        #expect(second.option.last == Option(name: "title", value: "Updated"))
        #expect(ledger.errors.isEmpty)
        #expect(first.errors.isEmpty)
        #expect(second.errors.isEmpty)
        #expect(try oldSnapshot.balance(in: ledger).amounts["USD"] == 0)
    }

    @Test
    func reparsingAddedDirectivesPreservesPreviousCollections() {
        let ledger = Parser.parse(string: Self.simple)
        let additions = """
        plugin "beancount.plugins.implicit_prices"
        2024-01-05 event "location" "Vancouver"
        2024-01-05 custom "setting" "retained"
        """
        let updated = Parser.parse(string: Self.simple + "\n" + additions)
        #expect(ledger.events.isEmpty)
        #expect(ledger.custom.isEmpty)
        #expect(ledger.plugins.isEmpty)
        #expect(updated.events.count == 1)
        #expect(updated.custom.count == 1)
        #expect(updated.plugins == ["beancount.plugins.implicit_prices"])
        #expect(updated.transactions.count == 1)
    }

    @Test
    func padIsMaterializedOnceWithoutExportingSyntheticTransaction() {
        let source = """
        2024-01-01 open Assets:Cash USD
        2024-01-01 open Equity:Opening USD
        2024-01-02 pad Assets:Cash Equity:Opening
        2024-01-03 balance Assets:Cash 10.00 USD
        """
        let ledger = Parser.parse(string: source)
        #expect(ledger.errors.isEmpty)
        #expect(ledger.transactions.count == 1)
        #expect(ledger.transactions.first?.metaData.flag == .complete)
        #expect(ledger.description == source)
        #expect(ledger.errors.isEmpty)
        #expect(ledger.transactions.count == 1)
    }

    @Test
    func includeSnapshotsSurviveExternalEditsAndReparse() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let root = directory.appendingPathComponent("main.bean")
        let child = directory.appendingPathComponent("child.bean")
        try Self.simple.write(to: child, atomically: true, encoding: .utf8)
        try "include \"child.bean\"\n".write(to: root, atomically: true, encoding: .utf8)
        let ledger = try Parser.parse(contentOf: root)
        let oldCount = ledger.transactions.count
        let childSource = Self.simple + "\n" + """
        2024-01-03 * "Appended"
          Assets:Cash 1 USD
          Equity:Opening -1 USD
        """
        try childSource.write(to: child, atomically: true, encoding: .utf8)
        let updated = try Parser.parse(contentOf: root)
        #expect(ledger.transactions.count == oldCount)
        #expect(updated.transactions.count == oldCount + 1)
        #expect(ledger.errors.isEmpty)
        #expect(ledger.description.contains("include \"child.bean\""))
    }

    @Test
    func unsupportedModelFeaturesProduceDiagnostics() {
        let average = Parser.parse(string: "2024-01-01 open Assets:Stock HOOL \"AVERAGE\"")
        #expect(average.errors.contains { $0.contains("unsupported booking method AVERAGE") })
        let currencies = Parser.parse(string: "2024-01-01 open Assets:Cash USD,EUR")
        #expect(currencies.errors.contains { $0.contains("multiple currencies") })
        let missing = Parser.parse(string: "include \"unavailable.bean\"")
        #expect(!missing.errors.isEmpty)
    }

}
#endif
