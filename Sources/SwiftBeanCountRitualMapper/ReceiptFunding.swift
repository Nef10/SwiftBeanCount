import Foundation
import RitualDownloader

struct ReceiptFunding {
    let paid: Decimal
    let companyBenefit: Decimal
    let bonusProgram: Decimal
    var vouchersAndCredits: Decimal { companyBenefit + bonusProgram }

    init(receipt: RitualReceipt) throws {
        let financialLabels: Set<String> = ["Subtotal", "Tax", "Tip", "Service Fee", "Discount", "Rebate", "Voucher", "Credits Applied", "Total"]
        var components = Decimal.zero, credits = Decimal.zero
        var vouchers: [Decimal] = [], total: Decimal?
        for line in receipt.totals where financialLabels.contains(line.label) {
            let value = try Self.money(line.amount)
            if line.label == "Total" {
                guard total == nil else {
                    throw RitualMappingError.invalidReceipt("Duplicated Total")
                }
                total = value
            } else {
                components += value
            }
            if line.label == "Voucher" || line.label == "Credits Applied" {
                guard value <= 0 else {
                    throw RitualMappingError.invalidReceipt("Positive Voucher / Credit amount")
                }
                if line.label == "Voucher" {
                    vouchers.append(-value)
                } else {
                    credits -= value
                }
            }
        }
        guard let total, total >= 0, components == total else {
            throw RitualMappingError.invalidReceipt(receipt.receiptID)
        }
        paid = total
        companyBenefit = vouchers.filter { $0 <= 25 }.max() ?? .zero
        bonusProgram = vouchers.reduce(.zero, +) - companyBenefit + credits
    }

    private static func money(_ text: String?) throws -> Decimal {
        guard var text else {
            throw RitualMappingError.invalidReceipt("Amount not present")
        }
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let pattern = #"^-?\$?(?:\d+|\d{1,3}(?:,\d{3})+)(?:\.\d{1,2})?$"#
        guard text.count <= 34, text.range(of: pattern, options: .regularExpression) != nil,
            let value = Decimal(
                string: text.replacingOccurrences(of: "$", with: "").replacingOccurrences(of: ",", with: ""),
                locale: Locale(identifier: "en_CA")
            )
        else {
            throw RitualMappingError.invalidReceipt("Invalid CAD amount")
        }
        return value
    }
}
