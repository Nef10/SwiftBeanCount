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

    let csvReader: CSVReader
    let fileName: String

    override var importName: String {
        fileName
    }

    private var loaded = false
    private var lines = [CSVLine]()

    required init(ledger: Ledger?, csvReader: CSVReader, fileName: String) {
        self.csvReader = csvReader
        self.fileName = fileName
        super.init(ledger: ledger)
    }

    override func load() {
        guard !loaded else {
            return
        }
        while csvReader.next() != nil {
            lines.append(parseLine())
        }
        lines.sort { $0.date > $1.date }
        loaded = true
    }

    override func nextTransaction() -> ImportedTransaction? {
        guard loaded, let data = lines.popLast() else {
            return nil
        }

        var description = sanitize(description: data.description)
        var categoryAccountName = try! AccountName(Settings.defaultAccountName) // swiftlint:disable:this force_try
        var payee = data.payee
        let originalPayee = payee
        let originalDescription = description

        let (savedDescription, savedPayee) = savedDescriptionAndPayeeFor(description: description)
        if let savedPayee = savedPayee {
            payee = savedPayee
        }
        if let savedDescription = savedDescription {
            description = savedDescription
        }
        if let accountName = savedAccountNameFor(payee: payee) {
            categoryAccountName = accountName
        }

        let categoryAmount = Amount(number: -data.amount, commoditySymbol: commoditySymbol, decimalDigits: 2)
        let flag: Flag = description == originalDescription && payee == originalPayee ? .incomplete : .complete
        let posting = Posting(accountName: configuredAccountName, amount: Amount(number: data.amount, commoditySymbol: commoditySymbol, decimalDigits: 2))
        var posting2: Posting
        if let price = data.price {
            let pricePer = Amount(number: categoryAmount.number / price.number, commoditySymbol: commoditySymbol, decimalDigits: 7)
            posting2 = Posting(accountName: categoryAccountName, amount: price, price: pricePer, cost: nil)
        } else {
            posting2 = Posting(accountName: categoryAccountName, amount: categoryAmount)
        }
        let transaction = Transaction(metaData: TransactionMetaData(date: data.date, payee: payee, narration: description, flag: flag), postings: [posting, posting2])
        return ImportedTransaction(transaction,
                                   originalDescription: originalDescription,
                                   possibleDuplicate: getPossibleDuplicateFor(transaction),
                                   shouldAllowUserToEdit: true,
                                   accountName: configuredAccountName)
    }

    func parseLine() -> CSVLine { // swiftlint:disable:this unavailable_function
        fatalError("Must Override")
    }

}
