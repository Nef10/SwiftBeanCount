//
//  SimpliiImporter.swift
//  SwiftBeanCountImporter
//
//  Created by Steffen Kötte on 2019-12-23.
//  Copyright © 2019 Steffen Kötte. All rights reserved.
//

import Foundation

class SimpliiImporter: CSVBaseImporter, CSVImporter {

    private static let description = "Transaction Details"
    private static let date = "Date"
    private static let amountIn = "Funds In"
    private static let amountOut = "Funds Out"

    static let headers = [[date, description, amountOut, amountIn]]

    override class var importerName: String { "Simplii" }
    override class var importerType: String { "simplii" }
    override class var helpText: String {
        """
        Enables importing of downloaded CSV files from Simplii Accounts.

        To use add \(Settings.importerTypeKey): "\(importerType)" to your account.
        """
    }

    private static var dateFormatter: DateFormatter = {
        var dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MM/dd/yyyy"
        return dateFormatter
    }()

    override var importName: String {
        "Simplii File \(fileName)"
    }

    override func parseLine() -> CSVLine {
        let date = Self.dateFormatter.date(from: csvReader[Self.date]!)!
        let description = csvReader[Self.description]!
        var amountString = csvReader[Self.amountIn]!
        if amountString.isEmpty {
            amountString = "-" + csvReader[Self.amountOut]!
        }
        let amount = Decimal(string: amountString, locale: Locale(identifier: "en_CA"))!
        let payee = description == "INTEREST" ? "Simplii" : ""
        return CSVLine(date: date, description: description, amount: amount, payee: payee, price: nil)
    }

}
