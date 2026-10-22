import SwiftBeanCountModel

/// A complete receipt transaction and the original bank transaction it can replace.
public struct RitualMappedTransaction {
    /// Balanced transaction with receipt information and preserved bank data.
    public let transaction: Transaction
    /// Original matching bank transaction, if any, for duplicate review.
    public let possibleDuplicate: Transaction?
}
