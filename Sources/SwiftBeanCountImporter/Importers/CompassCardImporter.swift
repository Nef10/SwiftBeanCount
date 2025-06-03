//
//  CompassCardImporter.swift
//
//
//  Created by Steffen Kötte on 2023-03-18.
//

import CSV
import Foundation
import SwiftBeanCountCompassCardMapper
import SwiftBeanCountModel

class CompassCardImporter: BaseImporter, CSVImporter {

    // swiftlint:disable:next line_length
    static let headers = [["DateTime", "Transaction", "Product", "LineItem", "Amount", "BalanceDetails", "JourneyId", "LocationDisplay", "TransactonTime", "OrderDate", "Payment", "OrderNumber", "AuthCode", "Total"]]

    override class var importerName: String { "Compass Card" }
    override class var importerType: String { "compass-card" }
    override class var helpText: String {
        """
        Imports Compass Card transactions from CSV files downloaded from the Compass Card website.

        The importer relies on meta data in your Beancount file to find your accounts. Please add `importer-type: "compass-card"` to your Compass Card Asset account.
        """
    }

    override var importName: String { "Compass Card File \(fileName)" }

    private let existingLedger: Ledger
    private let csvReader: CSVReader
    private let fileName: String

    /// Results
    private var transactions = [ImportedTransaction]()

    required init(ledger: Ledger?, csvReader: CSVReader, fileName: String) {
        existingLedger = ledger ?? Ledger()
        self.csvReader = csvReader
        self.fileName = fileName
        super.init(ledger: ledger)
    }

    override func load() {
        do {
            try mapTransactions(SwiftBeanCountCompassCardMapper(ledger: existingLedger).createTransactions(account: configuredAccountName, reader: csvReader))
        } catch {
            let group = DispatchGroup()
            group.enter()
            self.delegate?.error(error) {
                group.leave()
            }
            group.wait()
        }
    }

    private func mapTransactions(_ importedTransactions: [Transaction]) {
        transactions = importedTransactions.map {
            let description = $0.metaData.narration
            let (savedDescription, savedPayee) = savedDescriptionAndPayeeFor(description: description)
            let metaData = TransactionMetaData(date: $0.metaData.date,
                                               payee: savedPayee ?? $0.metaData.payee,
                                               narration: savedDescription ?? description,
                                               metaData: $0.metaData.metaData)
            let transaction = Transaction(metaData: metaData, postings: $0.postings)
            return ImportedTransaction(transaction,
                                       originalDescription: description,
                                       shouldAllowUserToEdit: true,
                                       accountName: configuredAccountName)
        }
    }

    override func nextTransaction() -> ImportedTransaction? {
        guard !transactions.isEmpty else {
            return nil
        }
        return transactions.removeFirst()
    }

}
