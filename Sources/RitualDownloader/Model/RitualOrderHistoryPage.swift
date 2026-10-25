import Foundation

/// An order summary used to decide whether its full receipt needs downloading.
public struct RitualOrderSummary: Equatable, Sendable {
    /// Stable receipt ID.
    public let receiptID: String
    /// Merchant display name.
    public let merchantName: String
    /// Local order date/time display string.
    public let dateTime: String
    /// Display payment amount.
    public let amount: String
    /// Optional display status.
    public let status: String?
}

/// A page of order summaries; cursors are opaque and copied unchanged.
public struct RitualOrderHistoryPage: Equatable, Sendable {
    /// Cursor for the next page, or nil at the end.
    public let nextCursor: String?
    /// Orders on the page, newest first in the observed API.
    public let orders: [RitualOrderSummary]
}
