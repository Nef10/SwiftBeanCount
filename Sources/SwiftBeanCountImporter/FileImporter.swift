//
//  FileImporter.swift
//  SwiftBeanCountImporter
//
//  Created by Steffen Kötte on 2017-08-28.
//  Copyright © 2017 Steffen Kötte. All rights reserved.
//

import Foundation
import SwiftBeanCountModel

/// The FileImporterFactory is responsible for the different types of `FileImporter`s.
/// It allow abstraction of the different importers by encapsulation to logic of which one to use.
enum FileImporterFactory {

    static var importers: [FileImporter.Type] {
        CSVImporterFactory.importers
    }

    /// Returns the correct FileImporter, or nil if the file cannot be imported
    /// - Parameters:
    ///   - ledger: existing ledger which is used to assist the import,
    ///             e.g. to read attributes of accounts
    ///   - url: URL of the file to import
    /// - Returns: FileImporter, or nil if the file cannot be imported
    static func new(ledger: Ledger?, url: URL?) -> FileImporter? {
        CSVImporterFactory.new(ledger: ledger, url: url)
    }

}

/// Protocol to represent an Importer which imports a file
protocol FileImporter: Importer {

}
