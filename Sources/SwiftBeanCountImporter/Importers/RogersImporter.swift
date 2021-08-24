//
//  RogersImporter.swift
//  SwiftBeanCountImporter
//
//  Created by Steffen Kötte on 2019-12-16.
//  Copyright © 2019 Steffen Kötte. All rights reserved.
//

import Foundation

class RogersImporter: CSVBaseImporter, CSVImporter {

    private static let description = "Merchant Name"
    private static let date1 = "Transaction Date"
    private static let date2 = "Date"
    private static let amount = "Amount"

    static let headers = [
        [date1, "Activity Type", description, "Merchant Category", amount],
        [date1, "Activity Type", description, "Merchant Category Description", amount],
        [date2, "Activity Type", description, "Merchant Category", amount],
        [date2, "Activity Type", description, "Merchant Category Description", amount],
        [date1, "Activity Type", description, "Merchant Category", amount, "Rewards"],
        [date1, "Activity Type", description, "Merchant Category Description", amount, "Rewards"],
        [date2, "Activity Type", description, "Merchant Category", amount, "Rewards"],
        [date2, "Activity Type", description, "Merchant Category Description", amount, "Rewards"],
    ]
    override class var settingsName: String { "Rogers CC" }

    private static var dateFormatter: DateFormatter = {
        var dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        return dateFormatter
    }()

    override var importName: String {
        "Rogers Bank File \(fileName)"
    }

    override func parseLine() -> CSVLine {
        let dateString = csvReader[Self.date1] ?? csvReader[Self.date2]!
        let date = Self.dateFormatter.date(from: dateString)!
        let description = csvReader[Self.description]!
        let amountString = csvReader[Self.amount]!
            .replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: ",", with: "")
        let amount = Decimal(string: amountString, locale: Locale(identifier: "en_CA"))!
        let payee = description == "CashBack / Remises" ? "Rogers" : ""
        return CSVLine(date: date, description: description, amount: -amount, payee: payee, price: nil)
    }

}
