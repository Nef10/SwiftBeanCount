//
//  CSVBaseImporter.swift
//  SwiftBeanCountImporter
//
//  Created by Steffen Kötte on 2020-05-10.
//  Copyright © 2020 Steffen Kötte. All rights reserved.
//

import CSV
import Foundation
import SwiftBeanCountModel

class CSVBaseImporter: BaseImporter {

    private static let regexe: [NSRegularExpression] = {  // swiftlint:disable force_try
        [
            try! NSRegularExpression(pattern: "(C-)?IDP PURCHASE( )?-( )?[0-9]{4}", options: []),
            try! NSRegularExpression(pattern: "VISA DEBIT (PUR|REF)-[0-9]{4}", options: []),
            try! NSRegularExpression(pattern: "WWWINTERAC PUR [0-9]{4}", options: []),
            try! NSRegularExpression(pattern: "INTERAC E-TRF- [0-9]{4}", options: []),
            try! NSRegularExpression(pattern: "[0-9]* ~ Internet Withdrawal", options: []),
            try! NSRegularExpression(pattern: "(-)? SAP(?! CANADA)", options: []),
            try! NSRegularExpression(pattern: "-( )?(MAY|JUNE)( )?201(4|6)", options: []),
            try! NSRegularExpression(pattern: "[^ ]*  BC  CA", options: []),
            try! NSRegularExpression(pattern: "#( )?[0-9]{1,5}", options: []),
        ]
    }() // swiftlint:enable force_try

    let csvReader: CSVReader
    let fileName: String

    private var loaded = false
    private var lines = [CSVLine]()

    required init(ledger: Ledger?, csvReader: CSVReader, fileName: String) {
        self.csvReader = csvReader
        self.fileName = fileName
        super.init(ledger: ledger)
    }

    func loadFile() {
        guard !loaded else {
            return
        }
        while csvReader.next() != nil {
            lines.append(parseLine())
        }
        lines.sort { $0.date > $1.date }
        loaded = true
    }

    func parseLineIntoTransaction() -> ImportedTransaction? {
        guard let accountName = accountName else {
            fatalError("No account configured")
        }
        guard loaded, let data = lines.popLast() else {
            return nil
        }
        var description = sanitizeDescription(data.description)
        var payee = data.payee
        let originalPayee = payee
        let originalDescription = description
        if let savedPayee = (UserDefaults.standard.dictionary(forKey: Settings.payeesUserDefaultKey) as? [String: String])?[description] {
            payee = savedPayee
        }
        if let savedDescription = (UserDefaults.standard.dictionary(forKey: Settings.descriptionUserDefaultsKey) as? [String: String])?[description] {
            description = savedDescription
        }

        let categoryAmount = Amount(number: -data.amount, commoditySymbol: commoditySymbol, decimalDigits: 2)
        var categoryAccountName = try! AccountName(Settings.defaultAccountName) // swiftlint:disable:this force_try
        if let accountNameString = (UserDefaults.standard.dictionary(forKey: Settings.accountsUserDefaultsKey) as? [String: String])?[payee],
            let accountName = try? AccountName(accountNameString) {
            categoryAccountName = accountName
        }
        let flag: Flag = description == originalDescription && payee == originalPayee ? .incomplete : .complete
        let transactionMetaData = TransactionMetaData(date: data.date, payee: payee, narration: description, flag: flag, tags: [])
        let amount = Amount(number: data.amount, commoditySymbol: commoditySymbol, decimalDigits: 2)
        let posting = Posting(accountName: accountName, amount: amount)
        var posting2: Posting
        if let price = data.price {
            let pricePer = Amount(number: categoryAmount.number / price.number, commoditySymbol: commoditySymbol, decimalDigits: 7)
            posting2 = Posting(accountName: categoryAccountName, amount: price, price: pricePer, cost: nil)
        } else {
            posting2 = Posting(accountName: categoryAccountName, amount: categoryAmount)
        }
        let transaction = Transaction(metaData: transactionMetaData, postings: [posting, posting2])
        return ImportedTransaction(transaction: transaction, originalDescription: originalDescription)
    }

    func parseLine() -> CSVLine { // swiftlint:disable:this unavailable_function
        fatalError("Must Override")
    }

    private func sanitizeDescription(_ description: String) -> String {
        var result = description
        for regex in Self.regexe {
            result = regex.stringByReplacingMatches(in: result,
                                                    options: .withoutAnchoringBounds,
                                                    range: NSRange(result.startIndex..., in: result),
                                                    withTemplate: "")
        }
        return result
    }

}
