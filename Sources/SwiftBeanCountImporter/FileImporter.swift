//
//  FileImporter.swift
//  SwiftBeanCountImporter
//
//  Created by Steffen Kötte on 2017-08-28.
//  Copyright © 2017 Steffen Kötte. All rights reserved.
//

import Foundation
import SwiftBeanCountModel

/// The FileImporterManager is responsible for the different types of `FileImporter`s.
/// It allow abstraction of the different importers by encapsulation to logic of which one to use.
public enum FileImporterManager {

    static var importers: [FileImporter.Type] {
        CSVImporterManager.importers
    }

    /// Returns the correct FileImporter, or nil if the file cannot be imported
    /// - Parameters:
    ///   - ledger: existing ledger which is used to assist the import,
    ///             e.g. to read attributes of accounts
    ///   - url: URL of the file to import
    /// - Returns: FileImporter, or nil if the file cannot be imported
    public static func new(ledger: Ledger?, url: URL?) -> FileImporter? {
        CSVImporterManager.new(ledger: ledger, url: url)
    }

}

/// Struct describing a transaction which has been imported
public struct ImportedTransaction {

    /// Transaction which has been imported
    public let transaction: Transaction

    /// The original description from the file. This is used to allow saving
    /// of description and payee mapping.
    public let originalDescription: String

}

/// Protocol to represent an Importer which imports a file
public protocol FileImporter: Importer {

    /// AccountName of the account the file belongs to
    ///
    /// You can use this to detect which posting the user should not edit
    var accountName: AccountName? { get }

    /// FileName of the file beeing imported
    var fileName: String { get }

    /// Loads the file into the memory
    ///
    /// You must call this method before you call `parseLineIntoTransaction()`.
    /// You might want to show a loading indicator during the loading of large files.
    func loadFile()

    /// Parses the next line into an `ImportedTransaction`.
    ///
    /// Returns nil when there are no more lines left.
    func parseLineIntoTransaction() -> ImportedTransaction?

}
