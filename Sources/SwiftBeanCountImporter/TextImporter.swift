//
//  TextImporter.swift
//  SwiftBeanCountImporter
//
//  Created by Steffen Kötte on 2020-05-10.
//  Copyright © 2020 Steffen Kötte. All rights reserved.
//

import Foundation
import SwiftBeanCountModel

/// The TextImporterFactory is responsible for the different types of `TextImporter`s.
/// It allow abstraction of the different importers by encapsulation to logic of which one to use.
enum TextImporterFactory {

    static var importers: [TransactionBalanceTextImporter.Type] {
        [ManuLifeImporter.self, EquatePlusImporter.self]
    }

    /// Returns the correct TextImporter, or nil if the text cannot be imported
    /// - Parameters:
    ///   - ledger: existing ledger which is used to assist the import,
    ///             e.g. to read attributes of accounts
    ///   - transaction: text of a transaction
    ///   - balance: text of a balance
    /// - Returns: TextImporter, or nil if the text cannot be imported
    static func new(ledger: Ledger?, transaction: String, balance: String) -> TextImporter? {
        if transaction.contains("flatexDEGIRO") {
            return EquatePlusImporter(ledger: ledger, transaction: transaction, balance: balance)
        }
        return ManuLifeImporter(ledger: ledger, transaction: transaction, balance: balance)
    }

}

protocol TransactionBalanceTextImporter: TextImporter {
    init(ledger: Ledger?, transaction: String, balance: String)
}

/// Protocol to represent an Importer which imports text
protocol TextImporter: Importer {

}
