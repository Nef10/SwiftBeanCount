//
//  RBCImporter.swift
//  SwiftBeanCountImporter
//
//  Created by Steffen Kötte on 2017-08-28.
//  Copyright © 2017 Steffen Kötte. All rights reserved.
//

import Foundation

class RBCImporter: CSVBaseImporter, CSVImporter {

    private static let description1 = "Description 1"
    private static let description2 = "Description 2"
    private static let date = "Transaction Date"
    private static let amount = "CAD$"

    static let headers = [["Account Type", "Account Number", date, "Cheque Number", description1, description2, amount, "USD$"]]

    override class var importerName: String { "RBC" }
    override class var importerType: String { "rbc" }
    override class var helpText: String {
        """
        Enables importing of downloaded CSV files from RBC Accounts and Credit Cards.

        To use add \(Settings.importerTypeKey): "\(importerType)" to your accounts.
        """
    }

    private static var dateFormatter: DateFormatter = {
        var dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "M/d/yyyy"
        return dateFormatter
    }()

    override var importName: String {
        "RBC File \(fileName)"
    }

    override func parseLine() -> CSVLine {
        let date = Self.dateFormatter.date(from: csvReader[Self.date]!)!
        let description = csvReader[Self.description1]! + " " + csvReader[Self.description2]!
        let amount = Decimal(string: csvReader[Self.amount]!, locale: Locale(identifier: "en_CA"))!
        let payee = description == "MONTHLY FEE " ? "RBC" : ""
        return CSVLine(date: date, description: description, amount: amount, payee: payee, price: nil)
    }

}
