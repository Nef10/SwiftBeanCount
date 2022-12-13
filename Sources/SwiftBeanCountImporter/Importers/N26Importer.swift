//
//  N26Importer.swift
//  SwiftBeanCountImporter
//
//  Created by Steffen Kötte on 2019-10-23.
//  Copyright © 2019 Steffen Kötte. All rights reserved.
//

import Foundation
import SwiftBeanCountModel

class N26Importer: CSVBaseImporter, CSVImporter {

    private static let description = "Verwendungszweck"
    private static let amount = "Betrag (EUR)"
    private static let amountForeignCurrency = "Betrag (Fremdwährung)"
    private static let foreignCurrency = "Fremdwährung"
    private static let exchangeRate = "Wechselkurs"
    private static let date = "Datum"
    private static let recipient = "Empfänger"

    static let headers = [[date, recipient, "Kontonummer", "Transaktionstyp", description, "Kategorie", amount, amountForeignCurrency, foreignCurrency, exchangeRate]]

    override class var importerName: String { "N26" }
    override class var importerType: String { "n26" }
    override class var helpText: String {
        """
        Enables importing of downloaded CSV files from N26 Accounts.

        To use add \(Settings.importerTypeKey): "\(importerType)" to your account.
        """
    }

    private static var dateFormatter: DateFormatter = {
        var dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        return dateFormatter
    }()

    override var importName: String {
        "N26 File \(fileName)"
    }

    override func parseLine() -> CSVLine {
        let date = Self.dateFormatter.date(from: csvReader[Self.date]!)!
        let description = "\(csvReader[Self.recipient]!) \(csvReader[Self.description]!)"
        let amount = Decimal(string: csvReader[Self.amount]!, locale: Locale(identifier: "en_CA"))!
        let amountForeignCurrency = Decimal(string: csvReader[Self.amountForeignCurrency]!, locale: Locale(identifier: "en_CA"))
        var price: Amount?
        if let amountForeignCurrency, csvReader[Self.foreignCurrency] != commoditySymbol {
            price = Amount(number: -amountForeignCurrency, commoditySymbol: csvReader[Self.foreignCurrency]!, decimalDigits: 2)
        }
        return CSVLine(date: date, description: description, amount: amount, payee: "", price: price)
    }

}
