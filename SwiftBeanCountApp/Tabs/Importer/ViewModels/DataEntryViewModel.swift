//
//  DataEntryViewModel.swift
//  SwiftBeanCountApp
//
//  Created by Steffen Kötte on 2024-12-18.
//

import Foundation
import SwiftBeanCountImporter
import SwiftBeanCountModel

struct DataEntryViewModel: Identifiable {

    private static let dateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        return dateFormatter
    }()

    let id = UUID()
    let importedTransaction: ImportedTransaction
    let dateString: String
    let amount: String

    let onImport: ((SwiftBeanCountModel.Transaction) -> Void)?
    let onSkip: (() -> Void)?
    let onAbort: (() -> Void)?

    var description: String
    var payee: String
    var saveDescriptionPayeeMapping = false
    var tags: String = ""
    var flag: String
    var account: String
    var saveAccountMapping = false

    init(importedTransaction: ImportedTransaction, onImport: ((SwiftBeanCountModel.Transaction) -> Void)? = nil, onSkip: (() -> Void)? = nil, onAbort: (() -> Void)? = nil) {
        self.importedTransaction = importedTransaction
        self.onImport = onImport
        self.onSkip = onSkip
        self.onAbort = onAbort

        let transaction = importedTransaction.transaction
        let metaData = transaction.metaData

        // Find the posting that is not the importer's own account
        let posting = transaction.postings.first { $0.accountName != importedTransaction.accountName }

        dateString = Self.dateFormatter.string(from: metaData.date)

        var priceString = ""
        if let posting, posting.price != nil {
            if posting.priceType == .total, let totalPrice = posting.totalPrice {
                priceString = " @@ \(String(describing: totalPrice))"
            } else if let price = posting.price {
                priceString = " @ \(String(describing: price))"
            }
        }
        amount = posting.map { String(describing: $0.amount) + priceString } ?? ""

        description = metaData.narration
        payee = metaData.payee
        flag = metaData.flag == .complete ? "*" : "!"
        account = posting?.accountName.fullName ?? ""
    }

    func buildTransaction(accountName: AccountName) -> SwiftBeanCountModel.Transaction? {
        let transaction = importedTransaction.transaction

        guard let posting = transaction.postings.first(where: { $0.accountName != importedTransaction.accountName }) else {
            return nil
        }

        let metaData = TransactionMetaData(date: transaction.metaData.date,
                                           payee: payee,
                                           narration: description,
                                           flag: flag == "*" ? .complete : .incomplete,
                                           tags: parseTags(),
                                           metaData: transaction.metaData.metaData)
        guard let newPosting = try? Posting(accountName: accountName,
                                            amount: posting.amount,
                                            price: posting.priceType == .total ? posting.totalPrice : posting.price,
                                            priceType: posting.priceType) else {
            return nil
        }
        var postings: [Posting] = transaction.postings.filter { $0 != posting }
        postings.append(newPosting)
        return Transaction(metaData: metaData, postings: postings)
    }

    private func parseTags() -> [Tag] {
        let tagStrings = Set(tags.components(separatedBy: CharacterSet.whitespacesAndNewlines))
        var tags = [Tag]()
        for tagString in tagStrings {
            guard !tagString.isEmpty else {
                continue
            }
            var tag = tagString
            if tagString.starts(with: "#") {
                tag = String(tagString.dropFirst())
            }
            tags.append(Tag(name: tag))
        }
        return tags
    }
}
