extension Ledger {
    package var retainedSourceDescription: String? {
        processedState?.sourceDescription
    }

    package func processedExactWeight(for posting: TransactionPosting) throws(PostingError) -> MultiCurrencyAmount? {
        try processedState?.exactWeight(for: posting, in: self)
    }

    package func containsPostingIdentity(_ posting: TransactionPosting) -> Bool {
        postingIdentities.contains(ObjectIdentifier(posting))
    }
}
