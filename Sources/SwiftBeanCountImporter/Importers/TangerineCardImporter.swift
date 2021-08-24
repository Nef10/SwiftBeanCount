//
//  TangerineCardImporter.swift
//  SwiftBeanCountImporter
//
//  Created by Steffen Kötte on 2020-04-05.
//  Copyright © 2020 Steffen Kötte. All rights reserved.
//

import Foundation

class TangerineCardImporter: CSVBaseImporter, CSVImporter {

    private static let date = "Transaction date"
    private static let name = "Name"
    private static let amount = "Amount"

    static let headers = [[date, "Transaction", name, "Memo", amount]]
    override class var settingsName: String { "Tangerine CC" }

    private static var dateFormatter: DateFormatter = {
        var dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "M/d/yyyy"
        return dateFormatter
    }()

    override var importName: String {
        "Tangerine Credit Card File \(fileName)"
    }

    override func parseLine() -> CSVLine {
        let date = Self.dateFormatter.date(from: csvReader[Self.date]!)!
        var description = ""
        description = csvReader[Self.name]!
        let amount = Decimal(string: csvReader[Self.amount]!, locale: Locale(identifier: "en_CA"))!
        return CSVLine(date: date, description: description, amount: amount, payee: "", price: nil)
    }

}
