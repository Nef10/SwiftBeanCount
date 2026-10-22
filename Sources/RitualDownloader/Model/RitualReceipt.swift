import Foundation

/// Identifies a failed receipt so callers can report partial imports explicitly.
public struct RitualReceiptFailure: LocalizedError, Equatable {
    /// Receipt which failed.
    public let receiptID: String
    /// Safe diagnostic with no credentials or saved response body.
    public let message: String

    public var errorDescription: String? { "Ritual receipt \(receiptID): \(message)" }
}

/// A purchased item; variants are kept for callers but excluded from narration.
public struct RitualReceiptItem: Codable, Equatable, Sendable {
    /// Number of items purchased.
    public let quantity: Int
    /// Main menu item description.
    public let itemName: String
    /// Modifier descriptions shown beneath the main item.
    public let variants: [String]
    /// Display price.
    public let price: String

    /// Creates a receipt item.
    public init(quantity: Int, itemName: String, price: String, variants: [String] = []) {
        self.quantity = quantity
        self.itemName = itemName
        self.variants = variants
        self.price = price
    }
}

/// A labelled totals row, including headers with no amount.
public struct RitualTotalsLine: Codable, Equatable, Sendable {
    /// Label, for example Voucher or Total.
    public let label: String
    /// Signed display amount, or nil for section headings.
    public let amount: String?

    /// Creates a totals row.
    public init(label: String, amount: String?) {
        self.label = label
        self.amount = amount
    }
}

/// A decoded receipt. Money and timestamps retain the server's display strings.
public struct RitualReceipt: Codable, Equatable, Sendable {
    /// Stable receipt identifier used for deduplication.
    public let receiptID: String
    /// Timestamp
    public let timestamp: Date
    /// Merchant's display name.
    public let merchantName: String
    /// Optional merchant address.
    public let merchantAddress: String?
    /// Display status; only completed orders become purchases.
    public let status: String?
    /// Purchased items and their variants.
    public let items: [RitualReceiptItem]
    /// Financial totals and other labelled display rows.
    public let totals: [RitualTotalsLine]

    /// Creates a receipt, including receipts decoded outside the downloader.
    public init(
        receiptID: String,
        dateTime: String,
        merchantName: String,
        status: String?,
        items: [RitualReceiptItem],
        totals: [RitualTotalsLine],
        merchantAddress: String? = nil
    ) throws {
        self.receiptID = receiptID
        self.timestamp = try RitualDateParser.date(from: dateTime)
        self.merchantName = merchantName
        self.merchantAddress = merchantAddress
        self.status = status
        self.items = items
        self.totals = totals
    }
}
