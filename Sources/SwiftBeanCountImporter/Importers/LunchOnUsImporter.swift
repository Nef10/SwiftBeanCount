//
//  LunchOnUsImporter.swift
//  SwiftBeanCountImporter
//
//  Created by Steffen Kötte on 2017-09-03.
//  Copyright © 2017 Steffen Kötte. All rights reserved.
//

import Foundation

class LunchOnUsImporter: CSVBaseImporter, CSVImporter {

    private static let date = "date"
    private static let type = "type"
    private static let amount = "amount"
    private static let description = "location"

    static let headers = [[date, type, amount, "invoice", "remaining", description]]

    override class var importerName: String { "Lunch On Us" }
    override class var importerType: String { "lunch-on-us" }
    override class var helpText: String {
        """
        Enables importing of CSV files downloaded from https://lunchmapper.appspot.com/csv. Does not support importing balances.

        To use add \(Settings.importerTypeKey): "\(importerType)" to your account.
        """
    }

    private static var dateFormatter: DateFormatter = {
        var dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM dd, yyyy | HH:mm:ss"
        return dateFormatter
    }()

    override var importName: String {
        "LunchOnUs File \(fileName)"
    }

    override func parseLine() -> CSVLine {
        let date = Self.dateFormatter.date(from: csvReader[Self.date]!)!
        var description = ""
        var payee = ""
        var sign = "-"
        if csvReader[Self.type]! == "Activate Card" {
            payee = "SAP Canada Inc."
            sign = "+"
            description = ""
        } else if csvReader[Self.type]! == "Cash Out" {
            description = "Cash Out"
        } else {
            description = csvReader[Self.description]!
        }
        let amount = Decimal(string: sign + csvReader[Self.amount]!, locale: Locale(identifier: "en_CA"))!
        return CSVLine(date: date, description: description, amount: amount, payee: payee, price: nil)
    }

}
