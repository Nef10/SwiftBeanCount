import Foundation
import RitualDownloader
import SwiftBeanCountModel

/// Converts completed Ritual receipts into balanced CAD ledger transactions.
public struct SwiftBeanCountRitualMapper {

    private static let dateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        return dateFormatter
    }()

    private let ledger: Ledger
    private let settings: RitualLedgerSettings
    /// IDs already imported, so the downloader can avoid requesting their details.
    public let knownReceiptIDs: Set<String>

    /// Creates a mapper and validates the three account roles in ledger metadata.
    public init(ledger: Ledger) throws {
        self.ledger = ledger
        self.knownReceiptIDs = Set(ledger.transactions.compactMap { $0.metaData.metaData["ritual-id"]?.lowercased() })
        settings = try RitualLedgerSettings(ledger: ledger)
    }

    /// Maps receipts chronologically, skipping imported IDs and non-completed orders.
    /// Matching uses merchant, date tolerance and the exact CAD card-paid amount.
    public func map(_ receipts: [RitualReceipt], dateTolerance: TimeInterval = 2 * 24 * 60 * 60) throws -> [RitualMappedTransaction] {
        var seen = knownReceiptIDs
        var matched = Set<ObjectIdentifier>()
        var result: [RitualMappedTransaction] = []
        let completed = try receipts.filter { receipt in
            guard receipt.status != nil else {
                throw RitualMappingError.invalidReceipt("Missing status")
            }
            return receipt.status?.hasPrefix("Order Completed") == true
        }
        let sorted = completed.map { ($0.timestamp, $0) }.sorted { ($0.0, $0.1.receiptID) < ($1.0, $1.1.receiptID) }
        for (date, receipt) in sorted where seen.insert(receipt.receiptID.lowercased()).inserted {
            let funding = try ReceiptFunding(receipt: receipt)
            let duplicate = payment(for: receipt, date: date, paid: funding.paid, tolerance: dateTolerance, matched: matched)
            let transaction = try create(receipt: receipt, date: date, funding: funding, duplicate: duplicate)
            if let duplicate {
                matched.insert(ObjectIdentifier(duplicate))
            }
            result.append(RitualMappedTransaction(transaction: transaction, possibleDuplicate: duplicate))
        }
        return result.sorted {
            ($0.transaction.metaData.date, $0.transaction.metaData.metaData["ritual-id"] ?? "")
                < ($1.transaction.metaData.date, $1.transaction.metaData.metaData["ritual-id"] ?? "")
        }
    }

    private func payment(for receipt: RitualReceipt, date: Date, paid: Decimal, tolerance: TimeInterval, matched: Set<ObjectIdentifier>) -> Transaction? {
        guard paid > 0 else {
            return nil
        }
        let candidates = ledger.transactions.filter { transaction in
            !matched.contains(ObjectIdentifier(transaction)) && transaction.metaData.metaData["ritual-id"] == nil
                && abs(transaction.metaData.date.timeIntervalSince(date)) <= tolerance && merchantsMatch(transaction.metaData.payee, receipt.merchantName)
                && transaction.postings.contains { isPayment($0, paid: paid) }
        }
        guard candidates.count == 1 else {
            // two matches will not randomly select one but instead return no duplicate
            return nil
        }
        let expenses = candidates.first!.postings.filter { $0.accountName.accountType == .expense }
        guard expenses.count == 1, let expense = expenses.first, expense.amount.commoditySymbol == "CAD", expense.price == nil, expense.cost == nil else {
            return nil
        }
        return candidates.first
    }

    private func isPayment(_ posting: Posting, paid: Decimal) -> Bool {
        (posting.accountName.accountType == .asset || posting.accountName.accountType == .liability) && posting.amount.commoditySymbol == "CAD"
            && posting.amount.number == -paid
    }

    private func merchantsMatch(_ bank: String, _ merchant: String) -> Bool {
        func normalized(_ name: String) -> String {
            name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_CA")).filter { $0.isLetter || $0.isNumber }
        }
        let bank = normalized(bank)
        let merchant = normalized(merchant)
        guard !bank.isEmpty, !merchant.isEmpty else {
            return false
        }
        return bank == merchant || bank == "ritual" || bank == "ritualco"
            || (min(bank.count, merchant.count) >= 4 && (bank.contains(merchant) || merchant.contains(bank)))
    }

    private func create(receipt: RitualReceipt, date: Date, funding: ReceiptFunding, duplicate: Transaction?) throws -> Transaction {
        var metadata = duplicate?.metaData.metaData ?? [:]
        metadata["ritual-id"] = receipt.receiptID
        let narration = try RitualDescription.narration(items: receipt.items)
        if let duplicate {
            if duplicate.metaData.date != date {
                metadata["ritual-order-date"] = Self.dateFormatter.string(from: date)
            }
            if !duplicate.metaData.narration.isEmpty, duplicate.metaData.narration != narration {
                metadata["ritual-original-narration"] = duplicate.metaData.narration
            }
            if duplicate.metaData.payee != receipt.merchantName {
                metadata["ritual-original-payee"] = duplicate.metaData.payee
            }
        }
        let header = TransactionMetaData(
            date: duplicate?.metaData.date ?? date,
            payee: receipt.merchantName,
            narration: narration,
            flag: duplicate?.metaData.flag ?? .complete,
            tags: duplicate?.metaData.tags ?? [],
            metaData: metadata
        )
        let postings = try expenseAndPaymentPostings(funding: funding, duplicate: duplicate) + incomePostings(funding)
        let transaction = Transaction(metaData: header, postings: postings)
        guard try transaction.balance(in: ledger).isZeroWithTolerance() else {
            throw RitualMappingError.invalidReceipt("Transaction does not balance")
        }
        return transaction
    }

    private func expenseAndPaymentPostings(funding: ReceiptFunding, duplicate: Transaction?) throws -> [Posting] {
        guard let duplicate else {
            var postings = [Posting(accountName: settings.expense, amount: cad(funding.paid + funding.vouchersAndCredits))]
            if funding.paid > 0 {
                postings.append(Posting(accountName: try AccountName("Assets:TODO"), amount: cad(-funding.paid)))
            }
            return postings
        }
        let expense = duplicate.postings.first { $0.accountName.accountType == .expense }!
        return duplicate.postings.map { posting -> Posting in
            guard posting === expense else {
                return posting
            }
            return Posting(
                accountName: expense.accountName,
                amount: cad(expense.amount.number + funding.vouchersAndCredits),
                metaData: expense.metaData
            )
        }
    }

    private func incomePostings(_ funding: ReceiptFunding) -> [Posting] {
        var postings: [Posting] = []
        if funding.companyBenefit > 0 {
            postings.append(Posting(accountName: settings.companyBenefit, amount: cad(-funding.companyBenefit)))
        }
        if funding.bonusProgram > 0 {
            postings.append(Posting(accountName: settings.bonusProgram, amount: cad(-funding.bonusProgram)))
        }
        return postings
    }

    private func cad(_ amount: Decimal) -> Amount {
        Amount(number: amount, commoditySymbol: "CAD", decimalDigits: 2)
    }

}
