#if RustLedger
import Foundation
@testable import SwiftBeanCountModel
import Testing

struct ProcessedLedgerStateTests {
    @Test
    func exactWeightsBelongToTheBuiltSnapshot() throws {
        let builder = LedgerBuilder()
        let transaction = makeTransaction()
        builder.add(transaction)
        let posting = try #require(transaction.postings.first)
        let exactWeight = MultiCurrencyAmount(amounts: [TestUtils.cad: 12.345], decimalDigits: [TestUtils.cad: 3])
        let ledger = builder.build(processed: ProcessedLedgerProjection(
            diagnostics: ["Rust validation diagnostic"],
            exactWeights: [ProcessedPostingWeight(posting: posting, amount: exactWeight)],
            sourceDescription: "original input text"
        ))

        #expect(ledger.ledgerErrors == ["Rust validation diagnostic"])
        #expect(try posting.balance(in: ledger) == exactWeight)
        #expect(ledger.description == "original input text")
    }

    @Test
    func missingExactWeightForSnapshotPostingIsAnError() throws {
        let builder = LedgerBuilder()
        let transaction = makeTransaction()
        builder.add(transaction)
        let ledger = builder.build(processed: ProcessedLedgerProjection(diagnostics: [], exactWeights: []))

        #expect(throws: PostingError.noCost("Rust-processed posting has no canonical weight: \(transaction.postings[0])")) {
            try transaction.balance(in: ledger)
        }
    }

    @Test
    func builderReuseDoesNotChangePriorProcessedSnapshot() throws {
        let builder = LedgerBuilder()
        let first = makeTransaction()
        builder.add(first)
        let firstWeight = MultiCurrencyAmount(amounts: [TestUtils.cad: 1], decimalDigits: [TestUtils.cad: 0])
        let firstCounterWeight = MultiCurrencyAmount(amounts: [TestUtils.cad: -1], decimalDigits: [TestUtils.cad: 0])
        let firstWeights = weights(for: first, primary: firstWeight, counter: firstCounterWeight)
        let oldSnapshot = builder.build(processed: projection("first", weights: firstWeights))

        let second = makeTransaction()
        builder.add(second)
        let secondWeight = MultiCurrencyAmount(amounts: [TestUtils.cad: 2], decimalDigits: [TestUtils.cad: 0])
        let secondCounterWeight = MultiCurrencyAmount(amounts: [TestUtils.cad: -2], decimalDigits: [TestUtils.cad: 0])
        let secondWeights = weights(for: second, primary: secondWeight, counter: secondCounterWeight)
        let newSnapshot = builder.build(processed: projection("second", weights: firstWeights + secondWeights))

        #expect(oldSnapshot.transactions.count == 1)
        #expect(oldSnapshot.ledgerErrors == ["first"])
        #expect(try first.postings[0].balance(in: oldSnapshot) == firstWeight)
        #expect(newSnapshot.transactions.count == 2)
        #expect(newSnapshot.ledgerErrors == ["second"])
        #expect(try first.postings[0].balance(in: newSnapshot) == firstWeight)
        #expect(try second.postings[0].balance(in: newSnapshot) == secondWeight)
    }

    private func makeTransaction() -> Transaction {
        let metaData = TransactionMetaData(date: TestUtils.date20170608, narration: "test", flag: .complete)
        return Transaction(metaData: metaData, postings: [
            Posting(accountName: TestUtils.cash, amount: Amount(number: 1, commoditySymbol: TestUtils.cad)),
            Posting(accountName: TestUtils.chequing, amount: Amount(number: -1, commoditySymbol: TestUtils.cad)),
        ])
    }

    private func weights(
        for transaction: Transaction,
        primary: MultiCurrencyAmount,
        counter: MultiCurrencyAmount
    ) -> [ProcessedPostingWeight] {
        [
            ProcessedPostingWeight(posting: transaction.postings[0], amount: primary),
            ProcessedPostingWeight(posting: transaction.postings[1], amount: counter),
        ]
    }

    private func projection(_ diagnostic: String, weights: [ProcessedPostingWeight]) -> ProcessedLedgerProjection {
        ProcessedLedgerProjection(diagnostics: [diagnostic], exactWeights: weights)
    }
}
#endif
