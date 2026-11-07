/// Exact posting accounting data supplied by the Rust adapter.
package struct ProcessedPostingWeight {
    package let posting: TransactionPosting
    package let amount: MultiCurrencyAmount

    package init(posting: TransactionPosting, amount: MultiCurrencyAmount) {
        self.posting = posting
        self.amount = amount
    }
}

/// Completed diagnostics and weights for one processed ledger snapshot.
package struct ProcessedLedgerProjection {
    package let diagnostics: [String]
    package let exactWeights: [ProcessedPostingWeight]
    package let sourceDescription: String?

    package init(
        diagnostics: [String],
        exactWeights: [ProcessedPostingWeight],
        sourceDescription: String? = nil
    ) {
        self.diagnostics = diagnostics
        self.exactWeights = exactWeights
        self.sourceDescription = sourceDescription
    }
}

package final class ProcessedLedgerState {
    let sourceDescription: String?
    private let exactWeights: [ObjectIdentifier: (TransactionPosting, MultiCurrencyAmount)]

    init(_ projection: ProcessedLedgerProjection) {
        sourceDescription = projection.sourceDescription
        exactWeights = Dictionary(
            projection.exactWeights.map { (ObjectIdentifier($0.posting), ($0.posting, $0.amount)) }
        ) { _, newest in newest }
    }

    func exactWeight(for posting: TransactionPosting, in ledger: Ledger) throws(PostingError) -> MultiCurrencyAmount? {
        guard ledger.containsPostingIdentity(posting) else {
            return nil
        }
        if let (retainedPosting, amount) = exactWeights[ObjectIdentifier(posting)], retainedPosting === posting {
            return amount
        }
        throw .noCost("Rust-processed posting has no canonical weight: \(posting)")
    }
}
