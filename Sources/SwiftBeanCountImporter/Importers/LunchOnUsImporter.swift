//
//  LunchOnUsImporter.swift
//  SwiftBeanCountImporter
//
//  Created by Steffen Kötte on 2017-09-03.
//  Copyright © 2017 Steffen Kötte. All rights reserved.
//

import Cocoa

class LunchOnUsImporter: CSVBaseImporter, CSVImporter {

    private static let date = "date"
    private static let type = "type"
    private static let amount = "amount"
    private static let description = "location"

    static let header = [date, type, amount, "invoice", "remaining", description]
    override class var settingsName: String { "LunchOnUs Card" }

    private static var dateFormatter: DateFormatter = {
        var dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM dd, yyyy | HH:mm:ss"
        return dateFormatter
    }()

    override func parseLine() -> CSVLine {
        let date = Self.dateFormatter.date(from: csvReader[Self.date]!)!
        var description = ""
        var payee = ""
        var sign = "-"
        if csvReader[Self.type]! == "Activate Card" {
            payee = "SAP Canada Inc."
            sign = "+"
            description = ""
        } else {
            description = csvReader[Self.description]!
        }
        let amount = Decimal(string: sign + csvReader[Self.amount]!, locale: Locale(identifier: "en_CA"))!
        return CSVLine(date: date, description: description, amount: amount, payee: payee, price: nil)
    }

}
