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

    static let header = [date, "Transaction", name, "Memo", amount]
    override class var settingsName: String { "Tangerine CC" }

    static let interac = "INTERAC e-Transfer From: "
    static let interest = "Interest Paid"

    private static var dateFormatter: DateFormatter = {
        var dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "M/d/yyyy"
        return dateFormatter
    }()

    override func parseLine() -> CSVLine {
        let date = Self.dateFormatter.date(from: csvReader[Self.date]!)!
        var description = ""
        description = csvReader[Self.name]!
        if csvReader[Self.name]!.starts(with: Self.interac) {
            description = "\(csvReader[Self.name]!.replacingOccurrences(of: Self.interac, with: "")) - \(description)"
        }
        let amount = Decimal(string: csvReader[Self.amount]!, locale: Locale(identifier: "en_CA"))!
        return CSVLine(date: date, description: description, amount: amount, payee: "", price: nil)
    }

}
