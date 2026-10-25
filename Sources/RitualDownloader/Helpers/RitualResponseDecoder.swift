import Foundation

/// Decoding of uncompressed Ritual protobuf responses
/// HTTP decompression is handled by URLSession before these bytes reach the decoder.
enum RitualResponseDecoder {

    /// Decodes operation 43, including opaque next-page cursors.
    static func history(_ data: Data) throws -> RitualOrderHistoryPage {
        let response = try ProtoMessage(data)
        let page = try response.message(49)
        guard response.integer(6) == 43, page.string(1) == "orderreceipts" else {
            throw RitualDownloadError.invalidResponse("Operation 43 is not an orderreceipts page")
        }
        let rows = try page.bytes(2).map { try ProtoMessage($0).messages(1) } ?? []
        let orders = try rows.map { row -> RitualOrderSummary in
            let card = try row.message(1).message(90)
            let actions = try card.messages(8)
            guard let action = actions.compactMap({ $0.string(6) }).first(where: { $0.hasPrefix("ritualco://ritnav/receipt?") }),
                let rid = receiptID(in: action, queryName: "receipt_id") else {
                throw RitualDownloadError.invalidResponse("History row has no receipt action")
            }
            return RitualOrderSummary(
                receiptID: rid,
                merchantName: try requiredText(card, [2, 1, 1]),
                dateTime: try requiredText(card, [3, 1, 1]),
                amount: try requiredText(card, [4, 1, 1]),
                status: try card.text([12, 3, 1, 1])
            )
        }
        return RitualOrderHistoryPage(nextCursor: page.string(3), orders: orders)
    }

    /// Decodes operation 201 and checks the response receipt ID when supplied by the server.
    static func receipt(_ data: Data, receiptID rid: String) throws -> RitualReceipt { // swiftlint:disable:this function_body_length
        let response = try ProtoMessage(data)
        guard response.integer(6) == 201 else {
            throw RitualDownloadError.invalidResponse("Expected receipt operation 201")
        }
        let receipt = try response.message(212).message(1)
        let groups = try receipt.messages(3)
        var items: [RitualReceiptItem] = []
        for group in groups {
            for item in try group.messages(2) {
                let quantityText = try requiredText(item, [1, 1])
                guard let quantity = Int(quantityText), quantity > 0 else {
                    throw RitualDownloadError.invalidResponse("Invalid receipt quantity: \(quantityText)")
                }
                let lines = try item.messages(2)
                guard let main = lines.first else {
                    throw RitualDownloadError.invalidResponse("Receipt item has no display rows")
                }
                let variants = try lines.dropFirst().compactMap { try $0.text([1, 1, 1]) }
                items.append(
                    RitualReceiptItem(
                        quantity: quantity,
                        itemName: try requiredText(main, [1, 1, 1]),
                        price: try requiredText(main, [2, 1, 1]),
                        variants: variants
                    )
                )
            }
        }
        let totals = try receipt.messages(4).compactMap { line -> RitualTotalsLine? in
            // Field 3 marks separators. A labelled row without an amount is a section heading.
            guard let label = try line.text([1, 1, 1]) else {
                return nil
            }
            return RitualTotalsLine(label: label, amount: try line.text([2, 1, 1]))
        }
        let emailActions = try receipt.messages(6).compactMap { $0.string(6) }
        if let action = emailActions.first(where: { $0.hasPrefix("ritualco://ritaction/emailreceipt?") }), receiptID(in: action, queryName: "rid") != rid {
            throw RitualDownloadError.invalidResponse("Receipt ID in response differs from request")
        }
        return try RitualReceipt(
            receiptID: rid,
            dateTime: try requiredText(receipt, [2, 1, 1]),
            merchantName: try requiredText(receipt, [8, 4]),
            status: try receipt.text([9, 3, 1, 1]),
            items: items,
            totals: totals,
            merchantAddress: try receipt.text([8, 6])
        )
    }

    private static func requiredText(_ message: ProtoMessage, _ path: [Int]) throws -> String {
        guard let text = try message.text(path) else { throw RitualDownloadError.invalidResponse("Missing UTF-8 text at protobuf path \(path)") }
        return text
    }

    private static func receiptID(in action: String, queryName: String) -> String? {
        URLComponents(string: action)?.queryItems?.first { $0.name == queryName }?.value
    }

}
