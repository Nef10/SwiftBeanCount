//
//  TangerineAccountImporter.swift
//  SwiftBeanCountImporter
//
//  Created by Steffen Kötte on 2017-08-28.
//  Copyright © 2017 Steffen Kötte. All rights reserved.
//

import Foundation
import SwiftBeanCountModel

class TangerineAccountImporter: CSVBaseImporter, CSVImporter {

    private static let date = "Date"
    private static let name = "Name"
    private static let memo = "Memo"
    private static let amount = "Amount"

    static let header = [date, "Transaction", name, memo, amount]
    override class var settingsName: String { "Tangerine Accounts" }

    static let interac = "INTERAC e-Transfer From: "
    static let interest = "Interest Paid"

    private static var dateFormatter: DateFormatter = {
        var dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "M/d/yyyy"
        return dateFormatter
    }()

    override func possibleAccountNames(for ledger: Ledger?) -> [AccountName] {
        if let accountName = accountName {
            return [accountName]
        }
        let possibleAccountNames = accountsFromSettings()
        let possibleAccounts = possibleAccountNames.compactMap { accountName in ledger?.accounts.first { $0.name == accountName } }
        for account in possibleAccounts {
            if let number = account.metaData["number"], fileName.contains(number) {
                return [account.name]
            }
        }
        return possibleAccountNames
    }

    override func parseLine() -> CSVLine {
        let date = Self.dateFormatter.date(from: csvReader[Self.date]!)!
        var description = ""
        var payee = ""
        if csvReader[Self.name]! == Self.interest {
            payee = "Tangerine"
        } else {
            description = csvReader[Self.memo]!
            if csvReader[Self.name]!.starts(with: Self.interac) {
                description = "\(csvReader[Self.name]!.replacingOccurrences(of: Self.interac, with: "")) - \(description)"
            }
        }
        let amount = Decimal(string: csvReader[Self.amount]!, locale: Locale(identifier: "en_CA"))!
        return CSVLine(date: date, description: description, amount: amount, payee: payee, price: nil)
    }

}
