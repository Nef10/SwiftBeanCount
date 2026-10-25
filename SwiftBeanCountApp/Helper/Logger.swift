//
//  Logger.swift
//  SwiftBeanCountApp
//
//  Created by Steffen Kötte on 2024-02-19.
//

import Foundation
import OSLog

extension Logger {
    private static var subsystem = Bundle.main.bundleIdentifier!

    static let ledger = Logger(subsystem: subsystem, category: "ledgerManagement")
    static let tax = Logger(subsystem: subsystem, category: "tax")
    static let files = Logger(subsystem: subsystem, category: "files")
    static let importer = Logger(subsystem: subsystem, category: "importer")
    static let payees = Logger(subsystem: subsystem, category: "payees")
}
