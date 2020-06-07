//
//  TextImporter.swift
//  SwiftBeanCountImporter
//
//  Created by Steffen Kötte on 2020-05-10.
//  Copyright © 2020 Steffen Kötte. All rights reserved.
//

import Foundation
import SwiftBeanCountModel

/// The TextImporterManager is responsible for the different types of `TextImporter`s.
/// It allow abstraction of the different importers by encapsulation to logic of which one to use.
public enum TextImporterManager {

    static var importers: [TransactionBalanceTextImporter.Type] {
        [ManuLifeImporter.self]
    }

    /// Returns a the correct TextImporter, or nil if the text cannot be imported
    /// - Parameters:
    ///   - ledger: existing ledger which is used to assist the import,
    ///             e.g. to read attributes of accounts
    ///   - transaction: text of a transaction
    ///   - balance: text of a balance
    /// - Returns: TextImporter, or nil if the text cannot be imported
    public static func new(ledger: Ledger?, transaction: String, balance: String) -> TextImporter? {
        ManuLifeImporter(ledger: ledger, transaction: transaction, balance: balance)
    }

}

protocol TransactionBalanceTextImporter: TextImporter {
    init(ledger: Ledger?, transaction: String, balance: String)
}

/// Protocol to represent an Importer which imports text
public protocol TextImporter: Importer {

    /// Parses the input Strings into a String which can be added to the ledger
    func parse() -> String

}
