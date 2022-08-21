//
//  DownloadImporterFactory.swift
//  SwiftBeanCountImporter
//
//  Created by Steffen Kötte on 2021-09-10.
//  Copyright © 2021 Steffen Kötte. All rights reserved.
//

import Foundation
import SwiftBeanCountModel

/// The DownloadImporterFactory is responsible for the different types of `DownloadImporter`s.
enum DownloadImporterFactory {

    static var importers: [DownloadImporter.Type] {
        #if canImport(UIKit) || canImport(AppKit)
            [WealthsimpleDownloadImporter.self, RogersDownloadImporter.self, TangerineDownloadImporter.self]
        #else
            [WealthsimpleDownloadImporter.self, RogersDownloadImporter.self]
        #endif
    }

    /// Returns the correct DownloadImporter
    /// - Parameters:
    ///   - ledger: existing ledger which is used to assist the import,
    ///             e.g. to read attributes of accounts
    ///   - name: Name of the importer to initialize
    /// - Returns: DownloadImporter, or nil if an importer with this name cannot be found
    static func new(ledger: Ledger?, name: String) -> DownloadImporter? {
        guard let importerClass = (Self.importers.first { $0.importerName == name }) else {
            return nil
        }
        return importerClass.init(ledger: ledger)
    }

}

protocol DownloadImporter: Importer {
    init(ledger: Ledger?)
}
